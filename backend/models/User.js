const mongoose = require("mongoose");

const UserSchema = new mongoose.Schema({
  // --- EXISTING BASIC FIELDS ---
  fullName: { type: String, required: true, trim: true },
  email: { type: String, required: true, unique: true, lowercase: true },
  password: { type: String, required: true },
  yearOfAttendance: { type: Number, required: true },

  // ✅ PROGRAMME DROPDOWN
  programmeTitle: {
    type: String,
    required: false,
    enum: [
      "Management Programme",
      "Computer Programme",
      "Financial Management",
      "Leadership Development Programme",
      "Public Administration and Management",
      "Public Administration and Policy (Advanced)",
      "Public Sector Management Course",
      "Performance Improvement Course",
      "Creativity and Innovation Course",
      "Mandatory & Executive Programmes",
      "Postgraduate Diploma in Public Administration and Management",
      "Other", // Allows selection of "Other"
    ],
  },

  // ✅ NEW FIELD: Stores the manual input when "Other" is selected
  customProgramme: { type: String, default: "" },

  isVerified: { type: Boolean, default: false },
  isAdmin: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now },
  certificateNumber: {
    type: String,
    required: true,
  },

  // --- 🆕 NEW PRO FIELDS ---
  profilePicture: { type: String, default: "" },
  bio: { type: String, default: "" },
  jobTitle: { type: String, default: "" },
  organization: { type: String, default: "" },
  linkedin: { type: String, default: "" },
  phoneNumber: { type: String, default: "" },
});

module.exports = mongoose.model("User", UserSchema);
