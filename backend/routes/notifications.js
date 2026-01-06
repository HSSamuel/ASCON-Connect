const router = require("express").Router();
const User = require("../models/User");
const verify = require("./verifyToken");

// POST /api/notifications/save-token
router.post("/save-token", verify, async (req, res) => {
  try {
    const { fcmToken } = req.body;
    if (!fcmToken) return res.status(400).send("Token required");

    // Update the user with their new phone token
    await User.findByIdAndUpdate(req.user._id, { fcmToken: fcmToken });

    res.status(200).send("Token saved");
  } catch (err) {
    console.error("Notification Token Error:", err);
    res.status(500).send(err.message);
  }
});

module.exports = router;
