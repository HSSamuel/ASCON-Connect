const router = require("express").Router();
const User = require("../models/User");
const verifyToken = require("./verifyToken");
const upload = require("../config/cloudinary"); // ✅ Import the Cloudinary config

// @route   PUT /api/profile/update
// @desc    Update profile info AND upload image
// middleware: verifyToken (Security) + upload.single (File Handling)
router.put(
  "/update",
  verifyToken,
  upload.single("profilePicture"),
  async (req, res) => {
    try {
      // 1. Prepare the text data from the form
      const updateData = {
        bio: req.body.bio,
        jobTitle: req.body.jobTitle,
        organization: req.body.organization,
        linkedin: req.body.linkedin,
        phoneNumber: req.body.phoneNumber,
      };

      // 2. IF a file was uploaded, Cloudinary gives us the 'path' (URL)
      // We save this URL to the database instead of the Base64 string.
      if (req.file) {
        updateData.profilePicture = req.file.path;
      }

      // 3. Update the user in MongoDB
      const updatedUser = await User.findByIdAndUpdate(
        req.user._id,
        { $set: updateData },
        { new: true } // Return the fresh, updated data
      );

      res.status(200).json(updatedUser);
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  }
);

// @route   GET /api/profile/me
// @desc    Get current user's full profile
router.get("/me", verifyToken, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select("-password");
    res.status(200).json(user);
  } catch (err) {
    res.status(500).json(err);
  }
});

module.exports = router;
