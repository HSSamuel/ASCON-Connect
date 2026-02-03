const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    fullName: { type: String, required: true, min: 6, max: 255 },
    email: { type: String, required: true, max: 255, min: 6 },
    password: { type: String, required: true, max: 1024, min: 6 },
    phoneNumber: { type: String, default: "" },

    isOnline: { type: Boolean, default: false },
    lastSeen: { type: Date, default: Date.now },
    isPhoneVisible: { type: Boolean, default: false },
    isEmailVisible: { type: Boolean, default: true },

    // ✅ NEW: Location Privacy Toggle
    isLocationVisible: { type: Boolean, default: false },

    isOpenToMentorship: { type: Boolean, default: false },

    programmeTitle: { type: String, required: false },
    customProgramme: { type: String, default: "" },
    yearOfAttendance: { type: Number, required: false },

    // ✅ NEW: Career & Skills for AI Matching
    industry: { type: String, default: "" }, // e.g. "Tech", "Finance", "Public Service"
    skills: { type: [String], default: [] }, // e.g. ["Leadership", "Project Management"]

    jobTitle: { type: String, default: "" },
    organization: { type: String, default: "" },

    // Address fields (Already existed in registration, but ensuring they are here)
    city: { type: String, default: "" },
    state: { type: String, default: "" },
    country: { type: String, default: "" },

    bio: { type: String, default: "" },
    linkedin: { type: String, default: "" },

    fcmTokens: { type: [String], default: [] },
    alumniId: { type: String, unique: true, sparse: true },
    hasSeenWelcome: { type: Boolean, default: false },

    isAdmin: { type: Boolean, default: false },
    isVerified: { type: Boolean, default: true },
    canEdit: { type: Boolean, default: false },
    profilePicture: { type: String, default: "" },

    provider: {
      type: String,
      default: "local",
      enum: ["local", "google"],
    },

    resetPasswordToken: { type: String },
    resetPasswordExpires: { type: Date },

    date: { type: Date, default: Date.now },
  },
  {
    timestamps: true,
  },
);

userSchema.index({ email: 1 });
userSchema.index({
  fullName: "text",
  jobTitle: "text",
  organization: "text",
  email: "text",
  alumniId: "text",
  industry: "text", // ✅ Index for faster search
  city: "text", // ✅ Index for location search
});

module.exports = mongoose.model("User", userSchema);
