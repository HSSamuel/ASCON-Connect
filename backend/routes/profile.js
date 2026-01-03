const router = require("express").Router();
const User = require("../models/User");
const verifyToken = require("./verifyToken");
const upload = require("../config/cloudinary");

// @route   PUT /api/profile/update
// @desc    Update profile info AND upload image
router.put("/update", verifyToken, (req, res) => {
  // ✅ WRAP THE UPLOAD IN A FUNCTION TO CATCH CONFIG ERRORS
  const uploadMiddleware = upload.single("profilePicture");

  uploadMiddleware(req, res, async (err) => {
    // 1. CATCH UPLOAD ERRORS (Missing Keys, File too large, etc.)
    if (err) {
      console.error("❌ UPLOAD CRASH:", err);
      return res.status(500).json({
        message: "Image upload failed. Check Cloudinary keys on Render.",
        error: err.message,
      });
    }

    // 2. IF UPLOAD SUCCEEDS, UPDATE DATABASE
    try {
      console.log("📥 RECEIVED DATA:", req.body);

      // Sanitize Year (Fixes the crashing bug from before)
      let year = req.body.yearOfAttendance;
      if (!year || year === "null" || year === "" || isNaN(year)) {
        year = null;
      }

      const updateData = {
        fullName: req.body.fullName,
        bio: req.body.bio,
        jobTitle: req.body.jobTitle,
        organization: req.body.organization,
        linkedin: req.body.linkedin,
        phoneNumber: req.body.phoneNumber,
        yearOfAttendance: year,
        programmeTitle: req.body.programmeTitle,
        customProgramme: req.body.customProgramme,
      };

      // Add Image URL if file exists
      if (req.file) {
        console.log("📸 NEW IMAGE:", req.file.path);
        updateData.profilePicture = req.file.path;
      }

      const updatedUser = await User.findByIdAndUpdate(
        req.user._id,
        { $set: updateData },
        { new: true, runValidators: true }
      ).select("-password");

      console.log("✅ PROFILE UPDATED");
      res.status(200).json(updatedUser);
    } catch (dbError) {
      console.error("❌ DATABASE ERROR:", dbError);
      res
        .status(500)
        .json({ message: "Database Error", error: dbError.message });
    }
  });
});

// @route   GET /api/profile/me
router.get("/me", verifyToken, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select("-password");
    res.status(200).json(user);
  } catch (err) {
    res.status(500).json(err);
  }
});

// @route   PUT /api/profile/welcome-seen
// @desc    Mark the user as having seen the welcome dialog
router.put("/welcome-seen", verifyToken, async (req, res) => {
  try {
    await User.findByIdAndUpdate(req.user._id, { hasSeenWelcome: true });
    res.status(200).json({ message: "Welcome status updated" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
