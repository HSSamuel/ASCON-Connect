// backend/models/Message.js
const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
  {
    conversationId: { type: String, required: true },
    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
    },

    type: {
      type: String,
      // ✅ Added 'poll' to allowed types
      enum: ["text", "image", "audio", "file", "poll"],
      default: "text",
    },

    text: { type: String, default: "" },
    fileUrl: { type: String, default: "" },
    fileName: { type: String, default: "" },

    // ✅ Reference to Poll if type === 'poll'
    pollId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Poll",
      default: null,
    },

    replyTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Message",
      default: null,
    },

    isRead: { type: Boolean, default: false },
    isEdited: { type: Boolean, default: false },

    // Soft Delete (Delete for Everyone)
    isDeleted: { type: Boolean, default: false },

    // Hidden For Specific Users (Delete for Me)
    deletedFor: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }],
  },
  { timestamps: true },
);

// Compound index for performance
messageSchema.index({ conversationId: 1, createdAt: -1 });

module.exports = mongoose.model("Message", messageSchema);
