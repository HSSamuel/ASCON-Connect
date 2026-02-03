const router = require("express").Router();
// ✅ NEW: Import the 3 separated models
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");

const verifyToken = require("./verifyToken");
const upload = require("../config/cloudinary");

// =========================================================
// 1. UPDATE PROFILE & SETTINGS
// =========================================================
// @route   PUT /api/profile/update
// @desc    Update profile info AND upload image
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
      console.log("📥 RECEIVED DATA:", req.body);

      // Sanitize Year
      let year = req.body.yearOfAttendance;
      if (!year || year === "null" || year === "" || isNaN(year)) {
        year = null;
      }

      // Handle Boolean Toggles
      const isMentor = req.body.isOpenToMentorship === "true";
      const isLocationVisible = req.body.isLocationVisible === "true";

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
        skills: skillsArray,
      };

      if (req.file) {
        console.log("📸 NEW IMAGE:", req.file.path);
        profileUpdateData.profilePicture = req.file.path;
      }

      // ✅ 2. PREPARE SETTINGS DATA
      const settingsUpdateData = {
        isLocationVisible: isLocationVisible,
        isOpenToMentorship: isMentor,
      };

      // ✅ 3. RUN BOTH UPDATES IN PARALLEL FOR SPEED
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

      console.log("✅ PROFILE UPDATED");
      // Merge results to send back to mobile app
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
// 2. GET MY PROFILE (Merged)
// =========================================================
// @route   GET /api/profile/me
router.get("/me", verifyToken, async (req, res) => {
  try {
    // ✅ Fetch from all 3 tables in parallel
    const [auth, profile, settings] = await Promise.all([
      UserAuth.findById(req.user._id).select("-password"),
      UserProfile.findOne({ userId: req.user._id }),
      UserSettings.findOne({ userId: req.user._id }),
    ]);

    if (!auth || !profile) {
      return res.status(404).json({ message: "User not found" });
    }

    // ✅ Merge the objects so the Mobile App doesn't need to change its code
    const fullProfile = {
      _id: auth._id,
      email: auth.email,
      isVerified: auth.isVerified,
      isAdmin: auth.isAdmin,
      isOnline: auth.isOnline,
      lastSeen: auth.lastSeen,
      ...profile.toObject(),
      ...settings.toObject(),
    };

    res.status(200).json(fullProfile);
  } catch (err) {
    res.status(500).json(err);
  }
});

// =========================================================
// 3. WELCOME STATUS
// =========================================================
// @route   PUT /api/profile/welcome-seen
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
