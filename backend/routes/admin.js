const router = require("express").Router();
const User = require("../models/User");
const verifyToken = require("./verifyToken"); // Import Token Checker
const verifyAdmin = require("./verifyAdmin"); // Import Admin Checker

// 1. GET ALL PENDING USERS (Protected)
// We add both middlewares here
router.get("/pending", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const pendingUsers = await User.find({ isVerified: false });
    res.json(pendingUsers);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// 2. APPROVE A USER (Protected)
router.put("/verify/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const updatedUser = await User.findByIdAndUpdate(
      req.params.id,
      { isVerified: true },
      { new: true }
    );
    res.json(updatedUser);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
