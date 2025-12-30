const router = require("express").Router();
const User = require("../models/User"); // Import the User model

// @route   GET /api/directory
// @desc    Get all verified alumni
// @access  Public (For now - we will secure this later)
router.get("/", async (req, res) => {
  try {
    // 1. Find all users where isVerified is TRUE
    // .select('-password') means "Don't send the passwords back!"
    const alumniList = await User.find({ isVerified: true })
      .select("-password")
      .sort({ yearOfAttendance: -1 }); // Newest first

    // 2. Send the list back to the App
    res.json(alumniList);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
