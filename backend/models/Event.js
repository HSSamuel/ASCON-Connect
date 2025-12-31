const mongoose = require("mongoose");

const EventSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: { type: String, required: true },
  date: { type: Date, required: true }, // When is it?
  location: { type: String, required: true }, // e.g., "Main Auditorium" or "Zoom"
  type: {
    type: String,
    default: "News",
    enum: ["Reunion", "Seminar", "News", "General"],
  },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Event", EventSchema);
