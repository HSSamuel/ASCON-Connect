const router = require("express").Router();
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const Notification = require("../models/Notification");
const verify = require("./verifyToken");
const Joi = require("joi");

// ==========================================
// 1. SAVE FCM TOKEN
// ==========================================
router.post("/save-token", verify, async (req, res) => {
  const schema = Joi.object({
    fcmToken: Joi.string().required(),
  }).unknown(true);

  const { error } = schema.validate(req.body);
  const token = req.body.fcmToken || req.body.token;

  if (error && !token) {
    return res
      .status(400)
      .json({ success: false, message: "Valid Token required" });
  }

  try {
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
// 2. GET NOTIFICATIONS (Filters out Deleted)
// ==========================================
router.get("/my-notifications", verify, async (req, res) => {
  try {
    const notifications = await Notification.find({
      $or: [{ recipientId: req.user._id }, { isBroadcast: true }],
      // ✅ FILTER: Exclude notifications deleted by this user
      deletedBy: { $ne: req.user._id },
    })
      .sort({ createdAt: -1 })
      .limit(30);

    const result = notifications.map((n) => {
      const isRead = n.isBroadcast ? n.readBy.includes(req.user._id) : n.isRead;

      return {
        ...n.toObject(),
        isRead: isRead,
      };
    });

    res.json({ success: true, data: result });
  } catch (err) {
    console.error("Fetch Notifications Error:", err);
    res
      .status(500)
      .json({ success: false, message: "Error fetching notifications" });
  }
});

// ==========================================
// 3. GET UNREAD COUNT (Smart Badge)
// ==========================================
router.get("/unread-count", verify, async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      $and: [
        // 1. Must be relevant to me
        {
          $or: [
            { recipientId: req.user._id, isRead: false },
            { isBroadcast: true, readBy: { $ne: req.user._id } },
          ],
        },
        // 2. ✅ MUST NOT be deleted by me
        { deletedBy: { $ne: req.user._id } },
      ],
    });

    res.json({ success: true, count: count });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ==========================================
// 4. MARK AS READ
// ==========================================
router.put("/:id/read", verify, async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);
    if (!notification) return res.status(404).json({ message: "Not found" });

    if (notification.isBroadcast) {
      await Notification.findByIdAndUpdate(req.params.id, {
        $addToSet: { readBy: req.user._id },
      });
    } else {
      if (
        notification.recipientId &&
        notification.recipientId.toString() === req.user._id.toString()
      ) {
        notification.isRead = true;
        await notification.save();
      }
    }
    res.json({ success: true, message: "Marked as read" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ==========================================
// 5. ✅ DELETE NOTIFICATION
// ==========================================
router.delete("/:id", verify, async (req, res) => {
  try {
    // We use "Soft Delete" (addToSet) so it disappears for this user
    // but stays for others (if broadcast).
    await Notification.findByIdAndUpdate(req.params.id, {
      $addToSet: { deletedBy: req.user._id },
    });

    res.json({ success: true, message: "Notification deleted" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
