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
    enum: ["News", "Event", "Webinar", "Reunion", "Seminar"],
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

// ✅ ADDED FIX: Automatically alias _id to id when sending data to the app
eventSchema.set("toJSON", {
  virtuals: true,
  transform: (doc, ret) => {
    ret.id = ret._id;
    return ret;
  },
});

module.exports = mongoose.model("Event", eventSchema);
