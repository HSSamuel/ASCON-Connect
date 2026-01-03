const mongoose = require("mongoose");

const eventSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
  },
  description: {
    type: String,
    required: true,
  },
  date: {
    type: Date,
    required: true,
  },
  location: {
    type: String,
    required: true,
    default: "ASCON Complex",
  },
  type: {
    type: String,
    enum: ["News", "Event", "Webinar"],
    default: "News",
  },
  // ✅ NEW FIELD: Stores the URL of the uploaded image
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

module.exports = mongoose.model("Event", eventSchema);
