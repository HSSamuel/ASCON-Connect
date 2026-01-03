const mongoose = require("mongoose");

const programmeSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    unique: true, // Prevents duplicate course names
    trim: true,
  },
  code: {
    type: String, // e.g., "RC", "ELC"
    required: false,
    uppercase: true,
  },
  description: {
    type: String,
    required: false,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("Programme", programmeSchema);
