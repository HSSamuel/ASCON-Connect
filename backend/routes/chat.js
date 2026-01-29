const router = require("express").Router();
const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const User = require("../models/User");
const verify = require("./verifyToken");

// ✅ FIX: Extract the actual Cloudinary object from the config wrapper
const cloudinaryConfig = require("../config/cloudinary");
const cloudinary = cloudinaryConfig.cloudinary;

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
    resource_type: "auto", // ✅ IMPORTANT: Allows Audio/Video/Images
  },
});

const upload = multer({ storage: storage });

// =========================================================
// ✅ MOVED TO TOP: SPECIFIC ROUTES FIRST!
// =========================================================

// ---------------------------------------------------------
// 1. CHECK UNREAD STATUS (Moved here to avoid wildcard collision)
// ---------------------------------------------------------
router.get("/unread-status", verify, async (req, res) => {
  try {
    // Find active conversations for this user
    const conversations = await Conversation.find({
      participants: req.user._id,
    }).select("_id");
    const conversationIds = conversations.map((c) => c._id);

    // Check if there is ANY unread message in those conversations sent by someone else
    const hasUnread = await Message.exists({
      conversationId: { $in: conversationIds },
      sender: { $ne: req.user._id },
      isRead: false,
    });

    // ✅ FORCE BOOLEAN: Ensure we return true/false
    res.status(200).json({ hasUnread: !!hasUnread });
  } catch (err) {
    res.status(500).json(err);
  }
});

// ---------------------------------------------------------
// 2. GET ALL CONVERSATIONS (Inbox)
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
// 3. START OR GET CONVERSATION
// ---------------------------------------------------------
router.post("/start", verify, async (req, res) => {
  const { receiverId } = req.body;
  try {
    let chat = await Conversation.findOne({
      isGroup: false,
      participants: { $all: [req.user._id, receiverId] },
    });

    if (chat) return res.status(200).json(chat);

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
// 4. BULK DELETE MESSAGES
// ---------------------------------------------------------
router.post("/delete-multiple", verify, async (req, res) => {
  try {
    const { messageIds } = req.body;
    if (!messageIds || messageIds.length === 0)
      return res.status(400).json("No IDs provided");

    // 1. Find messages that belong to this user
    const messages = await Message.find({
      _id: { $in: messageIds },
      sender: req.user._id,
    });

    if (messages.length === 0)
      return res.status(200).json({ message: "No messages to delete" });

    const validIds = messages.map((m) => m._id);
    const conversationId = messages[0].conversationId; // Assume all from same chat for simplicity

    // 2. Delete them
    await Message.deleteMany({ _id: { $in: validIds } });

    // 3. Emit Real-time Event
    _emitDeleteEvent(req, conversationId, validIds);

    res.status(200).json({ success: true, deletedIds: validIds });
  } catch (err) {
    console.error(err);
    res.status(500).json(err);
  }
});

// =========================================================
// ⚠️ DANGER ZONE: WILDCARD ROUTES (:id) MUST BE LAST
// =========================================================

// ---------------------------------------------------------
// 5. GET MESSAGES (Wildcard route)
// ---------------------------------------------------------
router.get("/:conversationId", verify, async (req, res) => {
  try {
    const { beforeId } = req.query;
    const limit = 20;
    let query = { conversationId: req.params.conversationId };

    if (beforeId) query._id = { $lt: beforeId };

    const messages = await Message.find(query)
      .sort({ createdAt: -1 })
      .limit(limit);

    res.status(200).json(messages.reverse());
  } catch (err) {
    res.status(500).json(err);
  }
});

// ---------------------------------------------------------
// 6. SEND A MESSAGE (Updated for Audio)
// ---------------------------------------------------------
router.post(
  "/:conversationId",
  verify,
  upload.single("file"),
  async (req, res) => {
    try {
      const { text, type } = req.body;
      let fileUrl = "";
      let fileName = ""; // ✅ NEW

      if (req.file) {
        fileUrl = req.file.path;
        fileName = req.file.originalname; // ✅ Capture original name (e.g. "MyCV.pdf")
      }

      const newMessage = new Message({
        conversationId: req.params.conversationId,
        sender: req.user._id,
        text: text || "",
        type: type || "text",
        fileUrl: fileUrl,
        fileName: fileName, // ✅ Save it
        isRead: false,
      });

      const savedMessage = await newMessage.save();

      // Better Previews
      let lastMessagePreview = text;
      if (type === "image") lastMessagePreview = "📷 Sent an image";
      if (type === "audio") lastMessagePreview = "🎤 Sent a voice note";
      if (type === "file") lastMessagePreview = "📎 Sent a document";

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

        // Push Notification
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
              senderId: req.user._id.toString(),
              senderName: sender.fullName,
              senderProfilePic: sender.profilePicture || "",
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
// 7. READ RECEIPT
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
// 8. DELETE CONVERSATION (Removes User from Chat)
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

// ---------------------------------------------------------
// 9. EDIT MESSAGE
// ---------------------------------------------------------
router.put("/message/:id", verify, async (req, res) => {
  try {
    const msg = await Message.findById(req.params.id);
    if (msg.sender.toString() !== req.user._id) {
      return res.status(403).json("Unauthorized");
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
// 10. DELETE SINGLE MESSAGE
// ---------------------------------------------------------
router.delete("/message/:id", verify, async (req, res) => {
  try {
    const msg = await Message.findById(req.params.id);
    if (!msg) return res.status(404).json("Not found");
    if (msg.sender.toString() !== req.user._id)
      return res.status(403).json("Unauthorized");

    await Message.findByIdAndDelete(req.params.id);
    _emitDeleteEvent(req, msg.conversationId, [msg._id]);

    res.status(200).json({ message: "Deleted" });
  } catch (err) {
    res.status(500).json(err);
  }
});

// Helper to emit delete events
async function _emitDeleteEvent(req, conversationId, messageIds) {
  const conversation = await Conversation.findById(conversationId);
  if (conversation) {
    conversation.participants.forEach((userId) => {
      if (userId.toString() !== req.user._id) {
        req.io.to(userId.toString()).emit("messages_deleted_bulk", {
          conversationId,
          messageIds,
        });
      }
    });
  }
}

module.exports = router;
