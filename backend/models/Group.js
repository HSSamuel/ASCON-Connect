const mongoose = require("mongoose");

const groupSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: { type: String },
  type: {
    type: String,
    enum: ["Chapter", "Interest", "Class"], // e.g., "Lagos Chapter", "Tech SIG", "Class of 2024"
    default: "Interest",
  },
  icon: { type: String, default: "" }, // URL to icon
  members: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }],
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Group", groupSchema);
