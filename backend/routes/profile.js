const router = require("express").Router();
const User = require("../models/User");
const verifyToken = require("./verifyToken"); // We will create this next

// @route   PUT /api/profile/update
// @desc    Update the logged-in user's details
router.put("/update", verifyToken, async (req, res) => {
  try {
    // We search for the user by the ID inside their token
    const updatedUser = await User.findByIdAndUpdate(
      req.user._id,
      {
        $set: {
          bio: req.body.bio,
          jobTitle: req.body.jobTitle,
          organization: req.body.organization, // ✅ Using 'organization'
          linkedin: req.body.linkedin,
          phoneNumber: req.body.phoneNumber,
          profilePicture: req.body.profilePicture,
        },
      },
      { new: true } // Return the fresh, updated data
    );

    res.status(200).json(updatedUser);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

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
