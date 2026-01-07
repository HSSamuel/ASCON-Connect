const router = require("express").Router();
const User = require("../models/User");
const verify = require("./verifyToken");

// POST /api/notifications/save-token
router.post("/save-token", verify, async (req, res) => {
  try {
    // We accept both keys just to be safe
    const token = req.body.fcmToken || req.body.token;

    if (!token) return res.status(400).send("Token required");

    // ✅ FIXED: Use $addToSet to add to the array (prevents duplicates)
    // We also keep the old 'fcmToken' field updated for backward compatibility if needed
    await User.findByIdAndUpdate(req.user._id, {
      $addToSet: { fcmTokens: token }, // Add to list
      fcmToken: token, // Update single field (legacy support)
    });

    res.status(200).send("Token saved");
  } catch (err) {
    console.error("Notification Token Error:", err);
    res.status(500).send(err.message);
  }
});

module.exports = router;
