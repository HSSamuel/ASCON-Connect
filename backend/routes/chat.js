const router = require("express").Router();
const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const verify = require("./verifyToken");

// Cloudinary Config
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
  params: async (req, file) => {
    console.log(`📤 Uploading: ${file.originalname} (${file.mimetype})`);

    let resourceType = "raw";

    if (file.mimetype.startsWith("image/")) {
      resourceType = "image";
    }

    if (
      file.originalname.match(
        /\.(pdf|doc|docx|xls|xlsx|ppt|pptx|zip|rar|txt)$/i,
      )
    ) {
      resourceType = "raw";
    }

    return {
      folder: "ascon_chat_files",
      resource_type: resourceType,
      public_id:
        file.originalname
          .replace(/\.[^/.]+$/, "")
          .replace(/[^a-zA-Z0-9]/g, "_") +
        "-" +
        Date.now(),
      format: resourceType === "raw" ? undefined : file.mimetype.split("/")[1],
    };
  },
});

const upload = multer({ storage: storage });

// =========================================================
// ✅ SPECIFIC ROUTES FIRST
// =========================================================

// ---------------------------------------------------------
// 1. CHECK UNREAD STATUS
// ---------------------------------------------------------
router.get("/unread-status", verify, async (req, res) => {
  try {
    const conversations = await Conversation.find({
      participants: req.user._id,
    }).select("_id");
    const conversationIds = conversations.map((c) => c._id);

    const hasUnread = await Message.exists({
      conversationId: { $in: conversationIds },
      sender: { $ne: req.user._id },
      isRead: false,
    });

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
    // 1. Fetch Conversations (Raw, no populate)
    const chats = await Conversation.find({
      participants: { $in: [req.user._id] },
    })
      .sort({ lastMessageAt: -1 })
      .lean();

    // 2. Extract all unique Participant IDs
    const allParticipantIds = new Set();
    chats.forEach((chat) => {
      chat.participants.forEach((pId) => allParticipantIds.add(pId.toString()));
    });

    // 3. Fetch User Profiles for these IDs
    const profiles = await UserProfile.find({
      userId: { $in: Array.from(allParticipantIds) },
    }).lean();

    // 4. Create a Lookup Map (Auth ID -> Profile Data)
    const profileMap = {};
    profiles.forEach((p) => {
      profileMap[p.userId.toString()] = p;
    });

    // 5. Enrich Chats with Profile Data
    const enrichedChats = chats.map((chat) => {
      const enrichedParticipants = chat.participants.map((pId) => {
        const idStr = pId.toString();
        const profile = profileMap[idStr];

        // Return structure matching what frontend expects
        return {
          _id: idStr,
          fullName: profile ? profile.fullName : "Alumni Member",
          profilePicture: profile ? profile.profilePicture : "",
          jobTitle: profile ? profile.jobTitle : "",
        };
      });

      return { ...chat, participants: enrichedParticipants };
    });

    res.json(enrichedChats);
  } catch (err) {
    console.error("Chat List Error:", err);
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

    if (!chat) {
      const newChat = new Conversation({
        participants: [req.user._id, receiverId],
      });
      chat = await newChat.save();
    }

    // ✅ Manually Populate Profiles
    const profiles = await UserProfile.find({
      userId: { $in: [req.user._id, receiverId] },
    }).lean();

    const profileMap = {};
    profiles.forEach((p) => (profileMap[p.userId.toString()] = p));

    const enrichedParticipants = chat.participants.map((pId) => {
      const idStr = pId.toString();
      const profile = profileMap[idStr];
      return {
        _id: idStr,
        fullName: profile ? profile.fullName : "Alumni Member",
        profilePicture: profile ? profile.profilePicture : "",
      };
    });

    // Return the chat object with enriched participants
    const responseObj = chat.toObject ? chat.toObject() : chat;
    responseObj.participants = enrichedParticipants;

    res.status(200).json(responseObj);
  } catch (err) {
    res.status(500).json(err);
  }
});

// ---------------------------------------------------------
// 4. BULK DELETE MESSAGES (HARD DELETE FROM DB)
// ---------------------------------------------------------
router.post("/delete-multiple", verify, async (req, res) => {
  try {
    const { messageIds, deleteForEveryone } = req.body;

    if (deleteForEveryone) {
      // 1. Delete for Everyone (Soft Delete Content)
      await Message.updateMany(
        { _id: { $in: messageIds }, sender: req.user._id }, // Can only delete own messages for everyone
        {
          $set: {
            isDeleted: true,
            text: "🚫 This message was deleted",
            fileUrl: null,
            type: "text",
          },
        },
      );
      // Emit event to update UI live
      const msg = await Message.findOne({ _id: messageIds[0] });
      if (msg) _emitDeleteEvent(req, msg.conversationId, messageIds, true);
    } else {
      // 2. Delete for Me (Hide from view)
      await Message.updateMany(
        { _id: { $in: messageIds } },
        { $addToSet: { deletedFor: req.user._id } },
      );
      // Emit event so local user sees change immediately
      const msg = await Message.findOne({ _id: messageIds[0] });
      if (msg) _emitDeleteEvent(req, msg.conversationId, messageIds, false);
    }

    res.status(200).json({ success: true });
  } catch (err) {
    res.status(500).json(err);
  }
});

// Update helper to send "mode"
async function _emitDeleteEvent(req, conversationId, messageIds, isHardDelete) {
  const conversation = await Conversation.findById(conversationId);
  if (conversation) {
    conversation.participants.forEach((userId) => {
      // Only emit hard deletes to everyone. Soft deletes only to self (handled by UI mostly)
      if (isHardDelete || userId.toString() === req.user._id) {
        req.io.to(userId.toString()).emit("messages_deleted_bulk", {
          conversationId,
          messageIds,
          isHardDelete,
        });
      }
    });
  }
}

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
    let query = {
      conversationId: req.params.conversationId,
      deletedFor: { $ne: req.user._id },
    };

    if (beforeId) query._id = { $lt: beforeId };

    const messages = await Message.find(query)
      .populate("sender", "fullName profilePicture") // ✅ ADDED: Populate Sender
      .populate("replyTo", "text sender type fileUrl")
      .populate("replyTo.sender", "fullName")
      .sort({ createdAt: -1 })
      .limit(limit);

    res.status(200).json(messages.reverse());
  } catch (err) {
    res.status(500).json(err);
  }
});

// ---------------------------------------------------------
// 6. SEND A MESSAGE (Updated for Reply & Edit)
// ---------------------------------------------------------
router.post(
  "/:conversationId",
  verify,
  upload.single("file"),
  async (req, res) => {
    try {
      const { text, type, replyToId } = req.body;
      let fileUrl = "";
      let fileName = "";

      if (req.file) {
        fileUrl = req.file.path;
        fileName = req.file.originalname;
      }

      const newMessage = new Message({
        conversationId: req.params.conversationId,
        sender: req.user._id,
        text: text || "",
        type: type || "text",
        fileUrl: fileUrl,
        fileName: fileName,
        replyTo: replyToId || null,
        isRead: false,
      });

      const savedMessage = await newMessage.save();

      // ✅ POPULATE SENDER DETAILS FOR FRONTEND
      await savedMessage.populate("sender", "fullName profilePicture");
      await savedMessage.populate({
        path: "replyTo",
        select: "text sender type",
        populate: { path: "sender", select: "fullName" },
      });

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
        // 1. Socket Emit
        req.io.to(receiverId.toString()).emit("new_message", {
          message: savedMessage,
          conversationId: conversation._id,
        });

        // 2. Push Notification
        const sender = await UserProfile.findOne({ userId: req.user._id });

        if (sender) {
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
// 8. DELETE CONVERSATION
// ---------------------------------------------------------
router.delete("/:conversationId", verify, async (req, res) => {
  try {
    const conversation = await Conversation.findByIdAndDelete(
      req.params.conversationId,
    );

    if (conversation) {
      await Message.deleteMany({ conversationId: req.params.conversationId });
    }

    res
      .status(200)
      .json({ message: "Conversation and messages permanently deleted." });
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
    if (!msg) return res.status(404).json("Not found");
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

    await Message.findByIdAndDelete(req.params.id);
    _emitDeleteEvent(req, msg.conversationId, [msg._id]);

    res.status(200).json({ message: "Deleted" });
  } catch (err) {
    res.status(500).json(err);
  }
});

module.exports = router;
