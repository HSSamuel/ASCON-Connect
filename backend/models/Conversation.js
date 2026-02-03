const mongoose = require("mongoose");

const conversationSchema = new mongoose.Schema(
  {
    participants: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }],
    lastMessage: { type: String, default: "" },
    lastMessageSender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
    }, // To indicate "You: ..."
    lastMessageAt: { type: Date, default: Date.now },
    isGroup: { type: Boolean, default: false },
    groupName: { type: String, default: "" },
    groupAdmin: { type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" },
  },
  { timestamps: true },
);

// Index for fast lookups of a user's chats
conversationSchema.index({ participants: 1 });
conversationSchema.index({ lastMessageAt: -1 });

module.exports = mongoose.model("Conversation", conversationSchema);
