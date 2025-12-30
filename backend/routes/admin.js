const router = require("express").Router();
const User = require("../models/User");

// 1. GET ALL PENDING USERS (Waiting for approval)
router.get("/pending", async (req, res) => {
  try {
    const pendingUsers = await User.find({ isVerified: false });
    res.json(pendingUsers);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// 2. APPROVE A USER (Flip the switch to true)
router.put("/verify/:id", async (req, res) => {
  try {
    const updatedUser = await User.findByIdAndUpdate(
      req.params.id,
      { isVerified: true },
      { new: true } // Return the updated version
    );
    res.json(updatedUser);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
