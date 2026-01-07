const router = require("express").Router();
const User = require("../models/User");
const Event = require("../models/Event");
const Programme = require("../models/Programme");
const ProgrammeInterest = require("../models/ProgrammeInterest");
const EventRegistration = require("../models/EventRegistration");
const jwt = require("jsonwebtoken");

// ✅ FIX 1: Import BOTH notification functions
const {
  sendBroadcastNotification,
  sendPersonalNotification,
} = require("../utils/notificationHandler");

// ==========================================
// 🛡️ MIDDLEWARE
// ==========================================

// 1. BASIC ADMIN CHECK (View Access)
const verifyAdmin = (req, res, next) => {
  const token = req.header("auth-token");
  if (!token) return res.status(401).json({ message: "Access Denied" });

  try {
    const verified = jwt.verify(token, process.env.JWT_SECRET);
    if (!verified.isAdmin) {
      return res.status(403).json({ message: "Admin privileges required." });
    }
    req.user = verified;
    next();
  } catch (err) {
    res.status(400).json({ message: "Invalid Token" });
  }
};

// 2. EDITOR CHECK (Write/Delete Access)
const verifyEditor = (req, res, next) => {
  const token = req.header("auth-token");
  if (!token) return res.status(401).json({ message: "Access Denied" });

  try {
    const verified = jwt.verify(token, process.env.JWT_SECRET);
    if (!verified.isAdmin)
      return res.status(403).json({ message: "Admin access required" });

    if (!verified.canEdit) {
      return res
        .status(403)
        .json({ message: "View Only: You do not have permission to edit." });
    }

    req.user = verified;
    next();
  } catch (err) {
    res.status(400).json({ message: "Invalid Token" });
  }
};

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

router.delete("/users/:id", verifyEditor, async (req, res) => {
  try {
    await User.findByIdAndDelete(req.params.id);
    res.json({ message: "User deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/users/:id/toggle-edit", verifyEditor, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    user.canEdit = !user.canEdit;
    await user.save();
    res.json({
      message: `Edit permission ${user.canEdit ? "GRANTED" : "REVOKED"}`,
      user,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/users/:id/toggle-admin", verifyEditor, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    user.isAdmin = !user.isAdmin;
    if (!user.isAdmin) user.canEdit = false;
    await user.save();
    res.json({
      message: `Admin Access ${user.isAdmin ? "GRANTED" : "REVOKED"}`,
      user,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ✅ VERIFY USER ROUTE (Updated)
router.put("/users/:id/verify", verifyEditor, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    if (user.isVerified) {
      return res.status(400).json({ message: "User is already verified." });
    }

    // Auto-Generate ID Logic (Legacy Support)
    if (!user.alumniId) {
      const targetYear = user.yearOfAttendance
        ? user.yearOfAttendance.toString()
        : new Date().getFullYear().toString();

      const regex = new RegExp(`ASC/${targetYear}/`);
      const lastUser = await User.findOne({ alumniId: { $regex: regex } }).sort(
        { _id: -1 }
      );

      let nextNum = 1;
      if (lastUser && lastUser.alumniId) {
        const parts = lastUser.alumniId.split("/");
        const lastNum = parseInt(parts[parts.length - 1]);
        if (!isNaN(lastNum)) nextNum = lastNum + 1;
      }

      const paddedNum = nextNum.toString().padStart(4, "0");
      user.alumniId = `ASC/${targetYear}/${paddedNum}`;
      if (!user.yearOfAttendance) user.yearOfAttendance = targetYear;
    }

    user.isVerified = true;
    await user.save();

    // ✅ FIX 2: Send Personal Notification to the User
    await sendPersonalNotification(
      user._id,
      "Account Verified! 🎉",
      "Your ASCON Alumni account has been approved. You can now access your Digital ID."
    );

    res.json({ message: "User Verified & Notified!", user });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 2. EVENT MANAGEMENT
// ==========================================

router.post("/events", verifyEditor, async (req, res) => {
  try {
    const { title, description, date, location, type, image } = req.body;

    const newEvent = new Event({
      title,
      description,
      date,
      location,
      type,
      image,
    });
    await newEvent.save();

    // 🔔 Send Broadcast
    await sendBroadcastNotification(
      `New ${type}: ${title}`,
      `Join us at ${location}! ${description.substring(0, 60)}...`,
      {
        route: "event_detail",
        id: newEvent._id.toString(),
      }
    );

    res
      .status(201)
      .json({ message: "Event created & Notified!", event: newEvent });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/events/:id", verifyEditor, async (req, res) => {
  try {
    const updatedEvent = await Event.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    res.json({ message: "Event updated!", event: updatedEvent });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.delete("/events/:id", verifyEditor, async (req, res) => {
  try {
    await Event.findByIdAndDelete(req.params.id);
    res.json({ message: "Event deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 3. PROGRAMME MANAGEMENT
// ==========================================

router.get("/programmes", async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const programmes = await Programme.find()
      .sort({ title: 1 })
      .skip(skip)
      .limit(limit);

    const total = await Programme.countDocuments();

    res.json({
      programmes,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post("/programmes", verifyEditor, async (req, res) => {
  try {
    const { title, code, description, duration, fee, image } = req.body;

    const exists = await Programme.findOne({ title });
    if (exists)
      return res.status(400).json({ message: "Programme already exists." });

    const newProg = new Programme({
      title,
      code,
      description,
      duration,
      fee,
      image,
    });
    await newProg.save();

    // 🔔 Send Broadcast
    await sendBroadcastNotification(
      `New Programme: ${title}`,
      `Enroll now for ${duration || "a limited time"}! ${description.substring(
        0,
        60
      )}...`,
      {
        route: "programme_detail",
        id: newProg._id.toString(),
      }
    );

    res
      .status(201)
      .json({ message: "Programme added & Notified!", programme: newProg });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.delete("/programmes/:id", verifyEditor, async (req, res) => {
  try {
    await Programme.findByIdAndDelete(req.params.id);
    res.json({ message: "Programme deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/programmes/:id", verifyEditor, async (req, res) => {
  try {
    const { title, code, description, duration, fee, image } = req.body;

    const updatedProg = await Programme.findByIdAndUpdate(
      req.params.id,
      { title, code, description, duration, fee, image },
      { new: true }
    );
    res.json({ message: "Programme updated!", programme: updatedProg });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// FORCE FIX ID ROUTE
router.put("/users/:id/fix-id", verifyEditor, async (req, res) => {
  try {
    const { year } = req.body;
    const user = await User.findById(req.params.id);

    if (!user) return res.status(404).json({ message: "User not found" });

    const targetYear = year
      ? year.toString()
      : new Date().getFullYear().toString();
    const regex = new RegExp(`ASC/${targetYear}/`);
    const lastUser = await User.findOne({ alumniId: { $regex: regex } }).sort({
      _id: -1,
    });

    let nextNum = 1;
    if (lastUser && lastUser.alumniId) {
      const parts = lastUser.alumniId.split("/");
      const lastNum = parseInt(parts[parts.length - 1]);
      if (!isNaN(lastNum)) nextNum = lastNum + 1;
    }
    const paddedNum = nextNum.toString().padStart(4, "0");
    const newId = `ASC/${targetYear}/${paddedNum}`;

    user.alumniId = newId;
    user.yearOfAttendance = targetYear;
    await user.save();

    res.json({ message: "ID Fixed Successfully!", user });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
