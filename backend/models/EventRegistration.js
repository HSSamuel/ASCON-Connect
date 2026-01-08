const mongoose = require("mongoose");

const EventRegistrationSchema = new mongoose.Schema({
  // ✅ Changed to ObjectId for proper database linking (joins)
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: false,
  },

  // Event Reference
  eventId: { type: String, required: true, index: true }, // Index added for faster lookups
  eventTitle: { type: String, required: true },
  eventType: { type: String, default: "Event" }, // e.g., Webinar, Reunion, Seminar

  // Personal Info
  fullName: { type: String, required: true, trim: true },
  email: {
    type: String,
    required: true,
    lowercase: true,
    trim: true,
    index: true,
  },
  phone: { type: String, required: true },

  // ✅ Made Enum more robust
  sex: {
    type: String,
    enum: ["Male", "Female", "Other", "Prefer not to say"],
    default: "Male",
  },

  // Professional Info
  organization: { type: String, trim: true },
  jobTitle: { type: String, trim: true },

  // Event Specifics
  specialRequirements: { type: String, trim: true },

  createdAt: { type: Date, default: Date.now },
});

// ✅ Composite Index: Prevents the same user from registering for the same event twice
EventRegistrationSchema.index({ eventId: 1, email: 1 }, { unique: true });

module.exports = mongoose.model("EventRegistration", EventRegistrationSchema);
