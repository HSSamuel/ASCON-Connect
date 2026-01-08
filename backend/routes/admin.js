const router = require("express").Router();
const User = require("../models/User");
const Event = require("../models/Event");
const Programme = require("../models/Programme");
const ProgrammeInterest = require("../models/ProgrammeInterest");
const EventRegistration = require("../models/EventRegistration");
const Notification = require("../models/Notification"); // ✅ Added for DB tracking
const jwt = require("jsonwebtoken");

// ✅ Notification Handler Imports
const {
  sendBroadcastNotification,
  sendPersonalNotification,
} = require("../utils/notificationHandler");

// ==========================================
// 🛡️ REFACTORED MIDDLEWARE
// ==========================================

// Base verification to avoid code duplication
const verifyTokenBase = (req, res, next) => {
  const token = req.header("auth-token");
  if (!token) return res.status(401).json({ message: "Access Denied" });

  try {
    const verified = jwt.verify(token, process.env.JWT_SECRET);
    req.user = verified;
    next();
  } catch (err) {
    res.status(400).json({ message: "Invalid Token" });
  }
};

const verifyAdmin = [
  verifyTokenBase,
  (req, res, next) => {
    if (!req.user.isAdmin)
      return res.status(403).json({ message: "Admin privileges required." });
    next();
  },
];

const verifyEditor = [
  verifyTokenBase,
  (req, res, next) => {
    if (!req.user.isAdmin)
      return res.status(403).json({ message: "Admin access required" });
    if (!req.user.canEdit)
      return res.status(403).json({ message: "View Only: Permission denied." });
    next();
  },
];

// ==========================================
// 📊 DASHBOARD STATS
// ==========================================
router.get("/stats", verifyAdmin, async (req, res) => {
  try {
    const [userCount, eventCount, progCount, progInterestCount, eventRegCount] =
      await Promise.all([
        User.countDocuments(),
        Event.countDocuments(),
        Programme.countDocuments(),
        ProgrammeInterest.countDocuments(),
        EventRegistration.countDocuments(),
      ]);

    res.json({
      users: userCount,
      events: eventCount,
      programmes: progCount,
      totalRegistrations: progInterestCount + eventRegCount,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 1. USER MANAGEMENT
// ==========================================

router.get("/users", verifyAdmin, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || "";

    let query = {};
    if (search) {
      query = {
        $or: [
          { fullName: { $regex: search, $options: "i" } },
          { email: { $regex: search, $options: "i" } },
          { alumniId: { $regex: search, $options: "i" } },
        ],
      };
    }

    const skip = (page - 1) * limit;
    const users = await User.find(query)
      .select("-password")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await User.countDocuments(query);

    res.json({
      users,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// VERIFY USER & GENERATE ID
router.put("/users/:id/verify", verifyEditor, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: "User not found" });
    if (user.isVerified)
      return res.status(400).json({ message: "Already verified." });

    // Auto-Generate ID Logic
    if (!user.alumniId) {
      const targetYear = user.yearOfAttendance || new Date().getFullYear();
      const regex = new RegExp(`ASC/${targetYear}/`);

      const lastUser = await User.findOne({ alumniId: { $regex: regex } }).sort(
        { alumniId: -1 }
      );

      let nextNum = 1;
      if (lastUser && lastUser.alumniId) {
        const parts = lastUser.alumniId.split("/");
        nextNum = parseInt(parts[parts.length - 1]) + 1;
      }

      const paddedNum = nextNum.toString().padStart(4, "0");
      user.alumniId = `ASC/${targetYear}/${paddedNum}`;
    }

    user.isVerified = true;
    await user.save();

    // ✅ SAVE TO DB for Notification Bell
    const notificationTitle = "Account Verified! 🎉";
    const notificationBody =
      "Your ASCON Alumni account has been approved. You can now access your Digital ID.";

    const newNotif = new Notification({
      recipientId: user._id,
      title: notificationTitle,
      message: notificationBody,
      isBroadcast: false,
    });
    await newNotif.save();

    // ✅ SEND PUSH
    await sendPersonalNotification(
      user._id,
      notificationTitle,
      notificationBody
    );

    res.json({ message: "User Verified, Notified & Logged!", user });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 2. EVENT MANAGEMENT
// ==========================================

router.post("/events", verifyEditor, async (req, res) => {
  try {
    const newEvent = new Event(req.body);
    await newEvent.save();

    const title = `New ${newEvent.type}: ${newEvent.title}`;
    const body = `Join us at ${newEvent.location}! Tap for details.`;

    // ✅ SAVE TO DB for Notification Bell (Broadcast)
    const broadcastNotif = new Notification({
      title: title,
      message: body,
      isBroadcast: true,
    });
    await broadcastNotif.save();

    // 🔔 SEND PUSH BROADCAST
    await sendBroadcastNotification(title, body, {
      route: "event_detail",
      id: newEvent._id.toString(),
    });

    res
      .status(201)
      .json({ message: "Event created & Broadcasted!", event: newEvent });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 3. PROGRAMME MANAGEMENT
// ==========================================

router.post("/programmes", verifyEditor, async (req, res) => {
  try {
    const exists = await Programme.findOne({ title: req.body.title });
    if (exists) return res.status(400).json({ message: "Programme exists." });

    const newProg = new Programme(req.body);
    await newProg.save();

    const title = `New Programme: ${newProg.title}`;
    const body = `New enrollment open: ${newProg.code}. Check it out!`;

    // ✅ SAVE TO DB
    const broadcastNotif = new Notification({
      title: title,
      message: body,
      isBroadcast: true,
    });
    await broadcastNotif.save();

    // 🔔 SEND PUSH
    await sendBroadcastNotification(title, body, {
      route: "programme_detail",
      id: newProg._id.toString(),
    });

    res.status(201).json({ message: "Programme added!", programme: newProg });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Standard DELETE and PUT routes (Keeping your logic)
router.delete("/users/:id", verifyEditor, async (req, res) => {
  try {
    await User.findByIdAndDelete(req.params.id);
    res.json({ message: "Deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/events/:id", verifyEditor, async (req, res) => {
  try {
    const event = await Event.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
    });
    res.json({ event });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
