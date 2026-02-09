const router = require("express").Router();
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");
const verifyToken = require("./verifyToken");
const upload = require("../config/cloudinary");

// ✅ Centralized Profile Completeness Logic
const calculateProfileCompleteness = (profile) => {
  let totalScore = 0;
  const maxScore = 8; // Score is out of 8 now

  if (profile.profilePicture) totalScore++;
  if (profile.jobTitle) totalScore++;
  if (profile.organization) totalScore++;
  if (profile.industry) totalScore++;
  if (profile.city) totalScore++;
  if (profile.bio) totalScore++;
  if (profile.linkedin) totalScore++;
  if (profile.dateOfBirth) totalScore++; // ✅ Added DOB Check

  const percent = totalScore / maxScore;
  return {
    percent: percent,
    isComplete: percent >= 0.85,
  };
};

// =========================================================
// 1. UPDATE PROFILE & SETTINGS
// =========================================================
router.put("/update", verifyToken, (req, res) => {
  const uploadMiddleware = upload.single("profilePicture");

  uploadMiddleware(req, res, async (err) => {
    if (err) {
      console.error("❌ UPLOAD CRASH:", err);
      return res.status(500).json({
        message: "Image upload failed. Check Cloudinary keys.",
        error: err.message,
      });
    }

    try {
      // Sanitize Year
      let year = req.body.yearOfAttendance;
      if (!year || year === "null" || year === "" || isNaN(year)) {
        year = null;
      }

      // Handle Boolean Toggles
      const isMentor = req.body.isOpenToMentorship === "true";
      const isLocationVisible = req.body.isLocationVisible === "true";
      const isBirthdayVisible = req.body.isBirthdayVisible === "true"; // ✅ New Flag

      // Handle Skills Array
      let skillsArray = [];
      if (req.body.skills && typeof req.body.skills === "string") {
        skillsArray = req.body.skills
          .split(",")
          .map((s) => s.trim())
          .filter((s) => s.length > 0);
      }

      // ✅ 1. PREPARE PROFILE DATA
      const profileUpdateData = {
        fullName: req.body.fullName,
        bio: req.body.bio,
        jobTitle: req.body.jobTitle,
        organization: req.body.organization,
        linkedin: req.body.linkedin,
        phoneNumber: req.body.phoneNumber,
        yearOfAttendance: year,
        programmeTitle: req.body.programmeTitle,
        customProgramme: req.body.customProgramme,
        industry: req.body.industry || "",
        city: req.body.city || "",
        state: req.body.state || "",
        skills: skillsArray,
      };

      // ✅ HANDLE DATE OF BIRTH
      if (req.body.dateOfBirth && req.body.dateOfBirth !== "null") {
        profileUpdateData.dateOfBirth = new Date(req.body.dateOfBirth);
      }

      if (req.file) {
        profileUpdateData.profilePicture = req.file.path;
      }

      // ✅ 2. PREPARE SETTINGS DATA
      const settingsUpdateData = {
        isLocationVisible: isLocationVisible,
        isOpenToMentorship: isMentor,
        isBirthdayVisible: isBirthdayVisible, // ✅ Save setting
      };

      // ✅ 3. RUN UPDATES IN PARALLEL
      const [updatedProfile, updatedSettings] = await Promise.all([
        UserProfile.findOneAndUpdate(
          { userId: req.user._id },
          { $set: profileUpdateData },
          { new: true, runValidators: true },
        ),
        UserSettings.findOneAndUpdate(
          { userId: req.user._id },
          { $set: settingsUpdateData },
          { new: true },
        ),
      ]);

      if (!updatedProfile) {
        return res.status(404).json({ message: "User profile not found" });
      }

      res
        .status(200)
        .json({ ...updatedProfile.toObject(), ...updatedSettings.toObject() });
    } catch (dbError) {
      console.error("❌ DATABASE ERROR:", dbError);
      res
        .status(500)
        .json({ message: "Database Error", error: dbError.message });
    }
  });
});

// =========================================================
// 2. GET MY PROFILE (With Calculated Stats)
// =========================================================
router.get("/me", verifyToken, async (req, res) => {
  try {
    const [auth, profile, settings] = await Promise.all([
      UserAuth.findById(req.user._id).select("-password"),
      UserProfile.findOne({ userId: req.user._id }),
      UserSettings.findOne({ userId: req.user._id }),
    ]);

    if (!auth || !profile) {
      return res.status(404).json({ message: "User not found" });
    }

    // ✅ NEW: Calculate stats on the server
    const completeness = calculateProfileCompleteness(profile);

    const fullProfile = {
      _id: auth._id,
      email: auth.email,
      isVerified: auth.isVerified,
      isAdmin: auth.isAdmin,
      isOnline: auth.isOnline,
      lastSeen: auth.lastSeen,
      ...profile.toObject(),
      ...settings.toObject(),
      // ✅ Inject calculated fields
      profileCompletionPercent: completeness.percent,
      isProfileComplete: completeness.isComplete,
    };

    res.status(200).json(fullProfile);
  } catch (err) {
    res.status(500).json(err);
  }
});

// =========================================================
// 3. WELCOME STATUS
// =========================================================
router.put("/welcome-seen", verifyToken, async (req, res) => {
  try {
    const settings = await UserSettings.findOneAndUpdate(
      { userId: req.user._id },
      { hasSeenWelcome: true },
    );

    if (!settings) {
      return res.status(404).json({ message: "User settings not found" });
    }

    res.status(200).json({ message: "Welcome status updated" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
