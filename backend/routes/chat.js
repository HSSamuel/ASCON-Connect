const router = require("express").Router();
const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const User = require("../models/User");
const verify = require("./verifyToken");

// 1. GET ALL CONVERSATIONS (Inbox)
router.get("/", verify, async (req, res) => {
  try {
    const chats = await Conversation.find({
      participants: { $in: [req.user._id] },
    })
      .populate("participants", "fullName profilePicture jobTitle") // Get names & pics
      .sort({ lastMessageAt: -1 }); // Newest first

    res.json(chats);
  } catch (err) {
    res.status(500).json(err);
  }
});

// 2. START OR GET CONVERSATION (When clicking "Message" on profile)
router.post("/start", verify, async (req, res) => {
  const { receiverId } = req.body;

  try {
    // Check if chat already exists
    let chat = await Conversation.findOne({
      isGroup: false,
      participants: { $all: [req.user._id, receiverId] },
    });

    if (chat) {
      return res.status(200).json(chat);
    }

    // Create new chat
    const newChat = new Conversation({
      participants: [req.user._id, receiverId],
    });

    const savedChat = await newChat.save();
    // Populate immediately so UI can use it
    const populatedChat = await Conversation.findById(savedChat._id).populate(
      "participants",
      "fullName profilePicture",
    );

    res.status(200).json(populatedChat);
  } catch (err) {
    res.status(500).json(err);
  }
});

// 3. GET MESSAGES FOR A CONVERSATION
router.get("/:conversationId", verify, async (req, res) => {
  try {
    const messages = await Message.find({
      conversationId: req.params.conversationId,
    })
      .sort({ createdAt: 1 }) // Oldest first (standard chat)
      .limit(100); // Limit to last 100 for performance

    res.status(200).json(messages);
  } catch (err) {
    res.status(500).json(err);
  }
});

// 4. SEND A MESSAGE (✅ Updated for Real-Time)
router.post("/:conversationId", verify, async (req, res) => {
  const newMessage = new Message({
    conversationId: req.params.conversationId,
    sender: req.user._id,
    text: req.body.text,
  });

  try {
    const savedMessage = await newMessage.save();

    // 1. Update Conversation "Last Message" & Get Updated Doc
    const conversation = await Conversation.findByIdAndUpdate(
      req.params.conversationId,
      {
        lastMessage: req.body.text,
        lastMessageSender: req.user._id,
        lastMessageAt: Date.now(),
      },
      { new: true }, // ✅ Important: Return the updated doc so we have participants
    );

    // ✅ 2. REAL-TIME: Emit to the Receiver
    // Find the participant who is NOT the sender
    const receiverId = conversation.participants.find(
      (id) => id.toString() !== req.user._id,
    );

    if (receiverId) {
      // Send to the specific room for that user
      // Note: We use req.io which we attached in server.js
      req.io.to(receiverId.toString()).emit("new_message", {
        message: savedMessage,
        conversationId: conversation._id,
      });
    }

    // TODO: Send Push Notification (FCM) here if user is offline

    res.status(200).json(savedMessage);
  } catch (err) {
    res.status(500).json(err);
  }
});

module.exports = router;
