const router = require("express").Router();
const User = require("../models/User");
const Notification = require("../models/Notification");
const verify = require("./verifyToken");
const Joi = require("joi"); // ✅ Added Joi

// ==========================================
// 1. SAVE FCM TOKEN (For Push Notifications)
// ==========================================
router.post("/save-token", verify, async (req, res) => {
  // Simple validation
  const schema = Joi.object({
    fcmToken: Joi.string().required(),
  }).unknown(true); // Allow other fields like 'token' for legacy

  const { error } = schema.validate(req.body);
  const token = req.body.fcmToken || req.body.token;

  if (error && !token) {
    return res
      .status(400)
      .json({ success: false, message: "Valid Token required" });
  }

  try {
    // Update user: add to array (no duplicates) and update legacy field
    await User.findByIdAndUpdate(req.user._id, {
      $addToSet: { fcmTokens: token },
      fcmToken: token,
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
    // Fetches personal notifications OR general broadcasts
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

// ==========================================
// 3. GET UNREAD COUNT (For Bell Badge)
// ==========================================
// ✅ ADDED THIS MISSING ENDPOINT
router.get("/unread-count", verify, async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      $or: [{ recipientId: req.user._id }, { isBroadcast: true }],
      readBy: { $ne: req.user._id }, // Assuming you have a 'readBy' array in your model for broadcasts
      // If your model is simple, this logic might need adjustment based on Schema
    });

    // Fallback logic if 'readBy' doesn't exist yet:
    // Just return 0 or rely on local storage logic in Flutter
    res.json({ success: true, count: count || 0 });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ==========================================
// 4. MARK AS READ
// ==========================================
// ✅ ADDED THIS MISSING ENDPOINT
router.put("/:id/read", verify, async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);
    if (!notification) return res.status(404).json({ message: "Not found" });

    // Logic: If it's a broadcast, add user ID to 'readBy'. If personal, set 'isRead'
    if (notification.isBroadcast) {
      await Notification.findByIdAndUpdate(req.params.id, {
        $addToSet: { readBy: req.user._id },
      });
    } else {
      notification.isRead = true;
      await notification.save();
    }

    res.json({ success: true, message: "Marked as read" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
