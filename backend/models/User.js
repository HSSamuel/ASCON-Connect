const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    fullName: { type: String, required: true, min: 6, max: 255 },
    email: { type: String, required: true, max: 255, min: 6 },
    password: { type: String, required: true, max: 1024, min: 6 },
    phoneNumber: { type: String, required: true },

    programmeTitle: { type: String, required: false },
    customProgramme: { type: String, default: "" },
    yearOfAttendance: { type: Number, required: false },

    jobTitle: { type: String, default: "" },
    organization: { type: String, default: "" },
    bio: { type: String, default: "" },
    linkedin: { type: String, default: "" },

    // Store the Phone's Notification Tokens for multi-device support
    fcmTokens: { type: [String], default: [] },

    // alumniId already creates a unique index due to 'unique: true'
    alumniId: { type: String, unique: true, sparse: true },
    hasSeenWelcome: { type: Boolean, default: false },

    isAdmin: { type: Boolean, default: false },
    isVerified: { type: Boolean, default: true },
    canEdit: { type: Boolean, default: false },
    profilePicture: { type: String, default: "" },

    // Fields for Password Reset logic (Security Improvement)
    resetPasswordToken: { type: String },
    resetPasswordExpires: { type: Date },

    date: { type: Date, default: Date.now },
  },
  {
    timestamps: true, // Automatically creates createdAt and updatedAt fields
  }
);

// ==========================================
// 🚀 PERFORMANCE INDEXING
// ==========================================

// 1. Single Field Index for high-speed lookups during Login
// (alumniId index is handled by the 'unique' property in the schema above)
userSchema.index({ email: 1 });

// 2. Text Index for the Directory Search functionality
userSchema.index({
  fullName: "text",
  jobTitle: "text",
  organization: "text",
});

module.exports = mongoose.model("User", userSchema);
