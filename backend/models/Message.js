const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
  {
    conversationId: { type: String, required: true },
    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    type: {
      type: String,
      enum: ["text", "image", "audio", "file"],
      default: "text",
    },

    text: { type: String, default: "" },
    fileUrl: { type: String, default: "" },

    isDeleted: { type: Boolean, default: false },
    isEdited: { type: Boolean, default: false },

    isRead: { type: Boolean, default: false },
  },
  { timestamps: true },
);

// ✅ CRITICAL PERFORMANCE FIX:
// Create a compound index so MongoDB can instantly find
// messages for a conversation and sort them by time.
messageSchema.index({ conversationId: 1, createdAt: -1 });

module.exports = mongoose.model("Message", messageSchema);
