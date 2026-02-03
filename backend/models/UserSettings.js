const mongoose = require("mongoose");

const userSettingsSchema = new mongoose.Schema(
  {
    // Link to the Auth Account
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
      unique: true,
    },

    // Privacy Toggles
    isPhoneVisible: { type: Boolean, default: false },
    isEmailVisible: { type: Boolean, default: true },
    isLocationVisible: { type: Boolean, default: false },

    // Features
    isOpenToMentorship: { type: Boolean, default: false },
    hasSeenWelcome: { type: Boolean, default: false },
  },
  { timestamps: true },
);

module.exports = mongoose.model("UserSettings", userSettingsSchema);
