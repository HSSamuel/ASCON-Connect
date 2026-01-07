const mongoose = require("mongoose");

const EventRegistrationSchema = new mongoose.Schema({
  eventId: { type: String, required: true },
  eventTitle: { type: String, required: true },
  eventType: { type: String, default: "Event" }, // e.g., Webinar, Reunion
  userId: { type: String }, // Optional, if logged in

  // Personal Info
  fullName: { type: String, required: true },
  email: { type: String, required: true },
  phone: { type: String, required: true },
  sex: { type: String, enum: ["Male", "Female"], default: "Male" },

  // Professional Info (Important for Seminars/Webinars)
  organization: { type: String },
  jobTitle: { type: String },

  // Event Specifics
  specialRequirements: { type: String }, // dietary, accessibility, etc.

  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("EventRegistration", EventRegistrationSchema);
