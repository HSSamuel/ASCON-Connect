const router = require("express").Router();
const User = require("../models/User");
const verifyToken = require("./verifyToken");
const upload = require("../config/cloudinary");

// @route   PUT /api/profile/update
// @desc    Update profile info AND upload image
router.put(
  "/update",
  verifyToken,
  upload.single("profilePicture"),
  async (req, res) => {
    try {
      // ✅ FIX: Add the missing fields here so they get saved to MongoDB
      const updateData = {
        bio: req.body.bio,
        jobTitle: req.body.jobTitle,
        organization: req.body.organization,
        linkedin: req.body.linkedin,
        phoneNumber: req.body.phoneNumber,
        yearOfAttendance: req.body.yearOfAttendance, // Added
        programmeTitle: req.body.programmeTitle, // Added
        customProgramme: req.body.customProgramme, // Added
      };

      // 2. IF a file was uploaded, save the Cloudinary URL
      if (req.file) {
        updateData.profilePicture = req.file.path;
      }

      // 3. Update the user in MongoDB
      const updatedUser = await User.findByIdAndUpdate(
        req.user._id,
        { $set: updateData },
        { new: true }
      );

      res.status(200).json(updatedUser);
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  }
);

// @route   GET /api/profile/me
router.get("/me", verifyToken, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select("-password");
    res.status(200).json(user);
  } catch (err) {
    res.status(500).json(err);
  }
});

module.exports = router;
