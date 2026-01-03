const mongoose = require("mongoose");

const userSchema = new mongoose.Schema({
  fullName: {
    type: String,
    required: true,
    min: 6,
    max: 255,
  },
  email: {
    type: String,
    required: true,
    max: 255,
    min: 6,
  },
  password: {
    type: String,
    required: true,
    max: 1024,
    min: 6,
  },
  phoneNumber: {
    type: String,
    required: true,
  },

  // ✅ Programme Details (required: false to prevent update crashes)
  programmeTitle: {
    type: String,
    required: false,
  },
  customProgramme: {
    type: String,
    default: "",
  },
  yearOfAttendance: {
    type: Number,
    required: false,
  },

  // ✅ Professional Details
  jobTitle: { type: String, default: "" },
  organization: { type: String, default: "" },
  bio: { type: String, default: "" },
  linkedin: { type: String, default: "" },

  // ✅ NEW: Remembers if they have seen the Welcome Dialog (Permanent Fix)
  hasSeenWelcome: { type: Boolean, default: false },

  // Admin & Security Fields
  isAdmin: { type: Boolean, default: false },
  isVerified: { type: Boolean, default: true },
  canEdit: { type: Boolean, default: false },

  // Profile Picture
  profilePicture: { type: String, default: "" },

  date: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("User", userSchema);
