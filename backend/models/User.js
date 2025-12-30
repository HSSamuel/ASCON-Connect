const mongoose = require("mongoose");

// This is the Blueprint for every ASCON Alumnus
const UserSchema = new mongoose.Schema({
  // 1. Full Name (Text)
  fullName: {
    type: String,
    required: true,
    trim: true,
  },

  // 2. Email Address (Unique ID)
  email: {
    type: String,
    required: true,
    unique: true, // This prevents two people from using the same email
    lowercase: true,
  },

  // 3. Password (Security)
  // We will encrypt this later. Never store plain text passwords!
  password: {
    type: String,
    required: true,
  },

  // 4. Year of Attendance (Number)
  // e.g., 2024
  yearOfAttendance: {
    type: Number,
    required: true,
  },

  // 5. Programme Title (The Dropdown)
  // We use 'enum' to strictly force the user to pick ONLY these options.
  // If they try to send "Cooking Class", the database will reject it.
  programmeTitle: {
    type: String,
    required: true,
    enum: [
      "Management Programme",
      "Computer Programme",
      "Financial Management",
      "Leadership Development Programme",
    ],
  },

  // 6. The Gatekeeper (Verification)
  // By default, this is FALSE. The user cannot login until Admin changes this to TRUE.
  isVerified: {
    type: Boolean,
    default: false,
  },

  // 7. System Data
  // Tracks when they signed up
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model("User", UserSchema);
