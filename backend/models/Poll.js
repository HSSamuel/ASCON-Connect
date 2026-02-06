const mongoose = require("mongoose");

const pollSchema = new mongoose.Schema({
  question: { type: String, required: true },
  options: [
    {
      text: { type: String, required: true },
      votes: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }], // Track who voted
    },
  ],
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" },
  isActive: { type: Boolean, default: true },
  expiresAt: { type: Date },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Poll", pollSchema);
