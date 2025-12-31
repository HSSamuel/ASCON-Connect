const mongoose = require("mongoose");

const UserSchema = new mongoose.Schema({
  // --- EXISTING BASIC FIELDS ---
  fullName: { type: String, required: true, trim: true },
  email: { type: String, required: true, unique: true, lowercase: true },
  password: { type: String, required: true },
  yearOfAttendance: { type: Number, required: true },
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
  isVerified: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now },

  // --- 🆕 NEW PRO FIELDS ---
  profilePicture: { type: String, default: "" }, // URL to the image
  bio: { type: String, default: "" },
  jobTitle: { type: String, default: "" },
  organization: { type: String, default: "" }, // ✅ CHANGED from 'company'
  linkedin: { type: String, default: "" },
  phoneNumber: { type: String, default: "" },
});

module.exports = mongoose.model("User", UserSchema);
