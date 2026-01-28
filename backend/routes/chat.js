const router = require("express").Router();
const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const User = require("../models/User");
const verify = require("./verifyToken");
const cloudinary = require("../config/cloudinary");
const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const { sendPersonalNotification } = require("../utils/notificationHandler"); // ✅ Import Notification Handler

// ---------------------------------------------------------
// 🛠️ SETUP FILE UPLOAD (Multer + Cloudinary)
// ---------------------------------------------------------
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "ascon_chat_files",
    // resource_type: "auto" allows uploading images, audio, and raw files
    resource_type: "auto",
  },
});

const upload = multer({ storage: storage });

// ---------------------------------------------------------
// 1. GET ALL CONVERSATIONS (Inbox)
// ---------------------------------------------------------
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

// ---------------------------------------------------------
// 2. START OR GET CONVERSATION (When clicking "Message" on profile)
// ---------------------------------------------------------
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

// ---------------------------------------------------------
// 3. GET MESSAGES FOR A CONVERSATION
// ---------------------------------------------------------
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

// ---------------------------------------------------------
// 4. SEND A MESSAGE (Supports Text, Images, Files & Push Notifs)
// ---------------------------------------------------------
router.post(
  "/:conversationId",
  verify,
  upload.single("file"),
  async (req, res) => {
    try {
      const { text, type } = req.body;
      let fileUrl = "";
      if (req.file) fileUrl = req.file.path;

      const newMessage = new Message({
        conversationId: req.params.conversationId,
        sender: req.user._id,
        text: text || "",
        type: type || "text",
        fileUrl: fileUrl,
        isRead: false, // <--- Default is FALSE
      });

      const savedMessage = await newMessage.save();

      let lastMessagePreview = text;
      if (type === "image") lastMessagePreview = "📷 Sent an image";
      if (type === "file") lastMessagePreview = "📎 Sent an attachment";

      const conversation = await Conversation.findByIdAndUpdate(
        req.params.conversationId,
        {
          lastMessage: lastMessagePreview,
          lastMessageSender: req.user._id,
          lastMessageAt: Date.now(),
        },
        { new: true },
      );

      // 1. REAL-TIME: Emit to the Receiver
      const receiverId = conversation.participants.find(
        (id) => id.toString() !== req.user._id,
      );

      if (receiverId) {
        req.io.to(receiverId.toString()).emit("new_message", {
          message: savedMessage,
          conversationId: conversation._id,
        });
      }

      // ✅ 2. PUSH NOTIFICATION (If user is offline)
      if (receiverId) {
        const receiver = await User.findById(receiverId);
        const sender = await User.findById(req.user._id);

        if (receiver && !receiver.isOnline) {
          await sendPersonalNotification(
            receiverId.toString(),
            `Message from ${sender.fullName}`, // Title
            lastMessagePreview, // Body
            {
              type: "chat_message",
              conversationId: conversation._id.toString(),
              senderId: req.user._id,
            },
          );
        }
      }

      res.status(200).json(savedMessage);
    } catch (err) {
      console.error("Send Error:", err);
      res.status(500).json(err);
    }
  },
);

// ---------------------------------------------------------
// ✅ 5. MARK CONVERSATION AS READ
// ---------------------------------------------------------
router.put("/read/:conversationId", verify, async (req, res) => {
  try {
    // Update all messages sent by the OTHER user to 'isRead: true'
    await Message.updateMany(
      {
        conversationId: req.params.conversationId,
        sender: { $ne: req.user._id }, // Not my messages
        isRead: false,
      },
      { $set: { isRead: true } },
    );

    // Notify the sender that I read their messages
    const conversation = await Conversation.findById(req.params.conversationId);
    const senderId = conversation.participants.find(
      (id) => id.toString() !== req.user._id,
    );

    if (senderId) {
      req.io.to(senderId.toString()).emit("messages_read", {
        conversationId: req.params.conversationId,
      });
    }

    res.status(200).json({ success: true });
  } catch (err) {
    res.status(500).json(err);
  }
});

// ---------------------------------------------------------
// 6. ✏️ EDIT MESSAGE
// ---------------------------------------------------------
router.put("/message/:id", verify, async (req, res) => {
  try {
    const msg = await Message.findById(req.params.id);

    // Security Check: Ensure user owns the message
    if (msg.sender.toString() !== req.user._id) {
      return res.status(403).json("You can only edit your own messages");
    }

    msg.text = req.body.text;
    msg.isEdited = true;

    // ✅ FIX: Originally you had deleteOne() here which destroys the message.
    // It must be save() to UPDATE it.
    await msg.save();

    // Optional: Emit an 'update_message' event if you want real-time edits
    // req.io.emit("message_updated", msg);

    res.status(200).json(msg);
  } catch (err) {
    res.status(500).json(err);
  }
});

// ---------------------------------------------------------
// 7. 🗑️ DELETE MESSAGE
// ---------------------------------------------------------
router.delete("/message/:id", verify, async (req, res) => {
  try {
    const msg = await Message.findById(req.params.id);

    // Security Check
    if (!msg) return res.status(404).json("Message not found");
    if (msg.sender.toString() !== req.user._id) {
      return res.status(403).json("You can only delete your own messages");
    }

    // ✅ HARD DELETE: Permanently remove from Database
    await Message.findByIdAndDelete(req.params.id);

    res
      .status(200)
      .json({ message: "Message permanently deleted", id: req.params.id });
  } catch (err) {
    res.status(500).json(err);
  }
});

module.exports = router;
