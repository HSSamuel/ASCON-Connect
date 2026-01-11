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
  // ✅ NEW FIELD: Location
  location: {
    type: String,
    trim: true,
    default: "ASCON Complex, Topo-Badagry", // Default fallback if admin leaves it empty
  },
  type: {
    type: String,
    // ✅ UPDATE: Added new professional terms
    enum: [
      "News",
      "Event",
      "Webinar",
      "Reunion",
      "Seminar",
      "Conference",
      "Workshop",
      "Symposium",
      "AGM",
      "Induction",
    ],
    default: "News",
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

eventSchema.set("toJSON", {
  virtuals: true,
  transform: (doc, ret) => {
    ret.id = ret._id;
    return ret;
  },
});

module.exports = mongoose.model("Event", eventSchema);
