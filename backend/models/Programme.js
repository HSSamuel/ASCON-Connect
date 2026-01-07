const mongoose = require("mongoose");

const programmeSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    unique: true,
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
  duration: {
    type: String,
    required: false,
  },
  fee: {
    type: String,
    required: false,
  },
  // ✅ ADDED: Image URL field
  image: {
    type: String,
    required: false,
    default: "",
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("Programme", programmeSchema);
