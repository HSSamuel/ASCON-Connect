const mongoose = require("mongoose");

const programmeSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    unique: true,
    trim: true,
  },
  code: {
    type: String,
    required: false,
    uppercase: true,
  },
  description: {
    type: String,
    required: false,
  },
  // ✅ NEW: Location moved here
  location: {
    type: String,
    required: true,
    default: "ASCON Complex, Badagry",
  },
  duration: {
    type: String,
    required: false,
  },
  fee: {
    type: String,
    required: false,
  },
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
