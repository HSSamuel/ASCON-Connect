const mongoose = require("mongoose");

const groupSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: { type: String, default: "" },
  type: {
    type: String,
    enum: ["Chapter", "Interest", "Class", "General"],
    default: "Interest",
  },
  icon: { type: String, default: "" },
  members: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }],
  // ✅ NEW: Track Admins specifically
  admins: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }],
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Group", groupSchema);
