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

    // ✅ NEW: Read Status
    isRead: { type: Boolean, default: false },
  },
  { timestamps: true },
);

module.exports = mongoose.model("Message", messageSchema);
