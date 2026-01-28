const router = require("express").Router();
const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const User = require("../models/User");
const verify = require("./verifyToken");
const cloudinary = require("../config/cloudinary");
const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const { sendPersonalNotification } = require("../utils/notificationHandler");

// ---------------------------------------------------------
// 🛠️ SETUP FILE UPLOAD (Multer + Cloudinary)
// ---------------------------------------------------------
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "ascon_chat_files",
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
      .populate("participants", "fullName profilePicture jobTitle")
      .sort({ lastMessageAt: -1 });

    res.json(chats);
  } catch (err) {
    res.status(500).json(err);
  }
});

// ---------------------------------------------------------
// 2. START OR GET CONVERSATION
// ---------------------------------------------------------
router.post("/start", verify, async (req, res) => {
  const { receiverId } = req.body;

  try {
    let chat = await Conversation.findOne({
      isGroup: false,
      participants: { $all: [req.user._id, receiverId] },
    });

    if (chat) {
      return res.status(200).json(chat);
    }

    const newChat = new Conversation({
      participants: [req.user._id, receiverId],
    });

    const savedChat = await newChat.save();
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
// ✅ 3. GET MESSAGES (WITH PAGINATION)
// ---------------------------------------------------------
router.get("/:conversationId", verify, async (req, res) => {
  try {
    const { beforeId } = req.query;
    const limit = 20;

    let query = { conversationId: req.params.conversationId };

    if (beforeId) {
      query._id = { $lt: beforeId };
    }

    const messages = await Message.find(query)
      .sort({ createdAt: -1 })
      .limit(limit);

    res.status(200).json(messages.reverse());
  } catch (err) {
    res.status(500).json(err);
  }
});

// ---------------------------------------------------------
// 4. SEND A MESSAGE
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
        isRead: false,
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

      const receiverId = conversation.participants.find(
        (id) => id.toString() !== req.user._id,
      );

      if (receiverId) {
        req.io.to(receiverId.toString()).emit("new_message", {
          message: savedMessage,
          conversationId: conversation._id,
        });
      }

      if (receiverId) {
        const receiver = await User.findById(receiverId);
        const sender = await User.findById(req.user._id);

        if (receiver && !receiver.isOnline) {
          await sendPersonalNotification(
            receiverId.toString(),
            `Message from ${sender.fullName}`,
            lastMessagePreview,
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
// 5. MARK CONVERSATION AS READ
// ---------------------------------------------------------
router.put("/read/:conversationId", verify, async (req, res) => {
  try {
    await Message.updateMany(
      {
        conversationId: req.params.conversationId,
        sender: { $ne: req.user._id },
        isRead: false,
      },
      { $set: { isRead: true } },
    );

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
// 6. EDIT MESSAGE
// ---------------------------------------------------------
router.put("/message/:id", verify, async (req, res) => {
  try {
    const msg = await Message.findById(req.params.id);

    if (msg.sender.toString() !== req.user._id) {
      return res.status(403).json("You can only edit your own messages");
    }

    msg.text = req.body.text;
    msg.isEdited = true;
    await msg.save();

    res.status(200).json(msg);
  } catch (err) {
    res.status(500).json(err);
  }
});

// ---------------------------------------------------------
// 7. HARD DELETE MESSAGE
// ---------------------------------------------------------
router.delete("/message/:id", verify, async (req, res) => {
  try {
    const msg = await Message.findById(req.params.id);

    if (!msg) return res.status(404).json("Message not found");
    if (msg.sender.toString() !== req.user._id) {
      return res.status(403).json("You can only delete your own messages");
    }

    await Message.findByIdAndDelete(req.params.id);

    const conversation = await Conversation.findById(msg.conversationId);
    if (conversation) {
      conversation.participants.forEach((userId) => {
        if (userId.toString() !== req.user._id) {
          req.io
            .to(userId.toString())
            .emit("message_deleted", { messageId: msg._id });
        }
      });
    }

    res
      .status(200)
      .json({ message: "Message permanently deleted", id: req.params.id });
  } catch (err) {
    res.status(500).json(err);
  }
});

// ---------------------------------------------------------
// ✅ 8. DELETE CONVERSATION (Removes User from Chat)
// ---------------------------------------------------------
router.delete("/:conversationId", verify, async (req, res) => {
  try {
    // Remove the current user from the participants list
    const conversation = await Conversation.findByIdAndUpdate(
      req.params.conversationId,
      { $pull: { participants: req.user._id } },
      { new: true },
    );

    // If NO participants are left, delete the conversation and all messages forever
    if (conversation && conversation.participants.length === 0) {
      await Conversation.findByIdAndDelete(req.params.conversationId);
      await Message.deleteMany({ conversationId: req.params.conversationId });
    }

    res.status(200).json({ message: "Conversation deleted from your list" });
  } catch (err) {
    res.status(500).json(err);
  }
});

module.exports = router;
