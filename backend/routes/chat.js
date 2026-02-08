// backend/routes/chat.js
const router = require("express").Router();
const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const Group = require("../models/Group");
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
    // 1. Fetch Conversations where user is a participant
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

    // 4. Create a Lookup Map
    const profileMap = {};
    profiles.forEach((p) => {
      profileMap[p.userId.toString()] = p;
    });

    // 5. Enrich Chats
    const enrichedChats = chats.map((chat) => {
      const enrichedParticipants = chat.participants.map((pId) => {
        const idStr = pId.toString();
        const profile = profileMap[idStr];

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

// =========================================================
// 1. START OR GET CONVERSATION (Updated for Groups)
// =========================================================
router.post("/start", verify, async (req, res) => {
  const { receiverId, groupId } = req.body;

  try {
    let chat;

    // A. HANDLE GROUP CHAT
    if (groupId) {
      chat = await Conversation.findOne({ groupId: groupId });

      if (!chat) {
        const group = await Group.findById(groupId);
        if (!group) return res.status(404).json({ message: "Group not found" });

        // Include ALL group members + current user
        let initialParticipants = group.members || [];
        if (!initialParticipants.some((id) => id.toString() === req.user._id)) {
          initialParticipants.push(req.user._id);
        }

        chat = new Conversation({
          isGroup: true,
          groupId: groupId,
          groupName: group.name,
          participants: initialParticipants,
          groupAdmin:
            group.admins && group.admins.length > 0
              ? group.admins[0]
              : req.user._id,
        });
        await chat.save();
      } else {
        // Ensure current user is in participants
        if (!chat.participants.includes(req.user._id)) {
          chat.participants.push(req.user._id);
          await chat.save();
        }
      }
    }
    // B. HANDLE 1-ON-1 CHAT
    else {
      chat = await Conversation.findOne({
        isGroup: false,
        participants: { $all: [req.user._id, receiverId] },
      });

      if (!chat) {
        chat = new Conversation({
          participants: [req.user._id, receiverId],
        });
        await chat.save();
      }
    }

    // Populate Response
    const participantIds = chat.participants;
    const profiles = await UserProfile.find({
      userId: { $in: participantIds },
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

    const responseObj = chat.toObject ? chat.toObject() : chat;
    responseObj.participants = enrichedParticipants;

    res.status(200).json(responseObj);
  } catch (err) {
    console.error("Start Chat Error:", err);
    res.status(500).json(err);
  }
});

// =========================================================
// 2. BULK DELETE MESSAGES
// =========================================================
router.post("/delete-multiple", verify, async (req, res) => {
  try {
    const { messageIds, deleteForEveryone } = req.body;
    const firstMsg = await Message.findById(messageIds[0]);
    if (!firstMsg)
      return res.status(404).json({ message: "Message not found" });

    const conversation = await Conversation.findById(firstMsg.conversationId);
    let isAdmin = false;

    if (conversation && conversation.groupId) {
      const group = await Group.findById(conversation.groupId);
      if (group && group.admins.includes(req.user._id)) {
        isAdmin = true;
      }
    }

    if (deleteForEveryone) {
      const query = { _id: { $in: messageIds } };
      if (!isAdmin) query.sender = req.user._id;

      await Message.updateMany(query, {
        $set: {
          isDeleted: true,
          text: "🚫 This message was deleted" + (isAdmin ? " by Admin" : ""),
          fileUrl: null,
          type: "text",
        },
      });

      _emitDeleteEvent(
        req,
        firstMsg.conversationId,
        messageIds,
        true,
        conversation,
      );
    } else {
      await Message.updateMany(
        { _id: { $in: messageIds } },
        { $addToSet: { deletedFor: req.user._id } },
      );
      _emitDeleteEvent(
        req,
        firstMsg.conversationId,
        messageIds,
        false,
        conversation,
      );
    }

    res.status(200).json({ success: true });
  } catch (err) {
    res.status(500).json(err);
  }
});

async function _emitDeleteEvent(
  req,
  conversationId,
  messageIds,
  isHardDelete,
  conversation,
) {
  if (!conversation) return;

  if (conversation.isGroup && conversation.groupId) {
    // ✅ Emit to Group Room
    req.io.to(conversation.groupId.toString()).emit("messages_deleted_bulk", {
      conversationId,
      messageIds,
      isHardDelete,
    });
  } else {
    // Emit to participants
    conversation.participants.forEach((userId) => {
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
// 5. GET MESSAGES
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
      .populate("sender", "fullName profilePicture")
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
// 6. SEND A MESSAGE (Fixed for Group Chats)
// ---------------------------------------------------------
router.post(
  "/:conversationId",
  verify,
  upload.single("file"),
  async (req, res) => {
    try {
      const { text, type, replyToId, pollId } = req.body;
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
        pollId: pollId || null, // ✅ Store Poll ID
        isRead: false,
      });

      const savedMessage = await newMessage.save();

      await savedMessage.populate("sender", "fullName profilePicture");
      await savedMessage.populate({
        path: "replyTo",
        select: "text sender type",
        populate: { path: "sender", select: "fullName" },
      });

      // Determine Preview Text
      let lastMessagePreview = text;
      if (type === "image") lastMessagePreview = "📷 Sent an image";
      if (type === "audio") lastMessagePreview = "🎤 Sent a voice note";
      if (type === "file") lastMessagePreview = "📎 Sent a document";
      if (type === "poll") lastMessagePreview = "📊 Created a poll";

      // 1. Update Conversation Stats
      const conversation = await Conversation.findByIdAndUpdate(
        req.params.conversationId,
        {
          lastMessage: lastMessagePreview,
          lastMessageSender: req.user._id,
          lastMessageAt: Date.now(),
        },
        { new: true },
      );

      // 2. Broadcast
      const senderProfile = await UserProfile.findOne({ userId: req.user._id });

      // ✅ OPTIMIZED GROUP BROADCASTING
      if (conversation.isGroup && conversation.groupId) {
        // A. Socket Emit to Room (One shot)
        // This ensures EVERYONE in the group (who is online) gets it.
        req.io.to(conversation.groupId.toString()).emit("new_message", {
          message: savedMessage,
          conversationId: conversation._id,
        });

        // B. Push Notifications
        const group = await Group.findById(conversation.groupId);
        if (group) {
          // Sync Participants if needed
          if (group.members.length !== conversation.participants.length) {
            conversation.participants = group.members;
            await conversation.save();
          }
        }

        conversation.participants.forEach(async (participantId) => {
          if (participantId.toString() === req.user._id) return;
          // Send Push Notification
          if (senderProfile) {
            try {
              await sendPersonalNotification(
                participantId.toString(),
                `${conversation.groupName} (${senderProfile.fullName})`,
                lastMessagePreview,
                {
                  type: "chat_message",
                  conversationId: conversation._id.toString(),
                  senderId: req.user._id.toString(),
                  isGroup: "true",
                },
              );
            } catch (e) {}
          }
        });
      } else {
        // Direct Message Handling
        conversation.participants.forEach(async (participantId) => {
          if (participantId.toString() === req.user._id) return;

          req.io.to(participantId.toString()).emit("new_message", {
            message: savedMessage,
            conversationId: conversation._id,
          });

          if (senderProfile) {
            try {
              await sendPersonalNotification(
                participantId.toString(),
                `Message from ${senderProfile.fullName}`,
                lastMessagePreview,
                {
                  type: "chat_message",
                  conversationId: conversation._id.toString(),
                  senderId: req.user._id.toString(),
                  isGroup: "false",
                },
              );
            } catch (e) {}
          }
        });
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

    // Broadcast Read Receipt
    if (conversation.isGroup && conversation.groupId) {
      req.io.to(conversation.groupId.toString()).emit("messages_read", {
        conversationId: req.params.conversationId,
        readerId: req.user._id,
      });
    } else {
      conversation.participants.forEach((participantId) => {
        if (participantId.toString() !== req.user._id) {
          req.io.to(participantId.toString()).emit("messages_read", {
            conversationId: req.params.conversationId,
            readerId: req.user._id,
          });
        }
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
    if (msg.sender.toString() !== req.user._id)
      return res.status(403).json("Unauthorized");

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

    // Get conversation for context to know if we emit to group room
    const conversation = await Conversation.findById(msg.conversationId);
    _emitDeleteEvent(req, msg.conversationId, [msg._id], true, conversation);

    res.status(200).json({ message: "Deleted" });
  } catch (err) {
    res.status(500).json(err);
  }
});

module.exports = router;
