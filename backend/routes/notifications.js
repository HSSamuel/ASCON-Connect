const router = require("express").Router();
const User = require("../models/User");
const Notification = require("../models/Notification");
const verify = require("./verifyToken"); // ✅ Imported as 'verify'

// ==========================================
// 1. SAVE FCM TOKEN (For Push Notifications)
// ==========================================
router.post("/save-token", verify, async (req, res) => {
  try {
    // Accept fcmToken or token from the body
    const token = req.body.fcmToken || req.body.token;

    if (!token) {
      return res
        .status(400)
        .json({ success: false, message: "Token required" });
    }

    // Update user: add to array (no duplicates) and update legacy field
    await User.findByIdAndUpdate(req.user._id, {
      $addToSet: { fcmTokens: token },
      fcmToken: token, // Backward compatibility
    });

    res
      .status(200)
      .json({ success: true, message: "Token saved successfully" });
  } catch (err) {
    console.error("Notification Token Error:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ==========================================
// 2. GET NOTIFICATIONS (Authenticated)
// ==========================================
router.get("/my-notifications", verify, async (req, res) => {
  try {
    // Fetches notifications sent specifically to this user OR general broadcasts
    const notifications = await Notification.find({
      $or: [{ recipientId: req.user._id }, { isBroadcast: true }],
    })
      .sort({ createdAt: -1 })
      .limit(20);

    res.json({ success: true, data: notifications });
  } catch (err) {
    console.error("Fetch Notifications Error:", err);
    res
      .status(500)
      .json({ success: false, message: "Error fetching notifications" });
  }
});

module.exports = router;
