const router = require("express").Router();
const User = require("../models/User");
const Event = require("../models/Event");
const Programme = require("../models/Programme");
const jwt = require("jsonwebtoken");
const admin = require("../config/firebase");

// ==========================================
// MIDDLEWARE
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
// 1. USER MANAGEMENT
// ==========================================

// GET ALL USERS (With Search & Pagination)
router.get("/users", verifyAdmin, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || ""; // ✅ Added Search

    // Build Query
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

// DELETE USER
router.delete("/users/:id", verifyEditor, async (req, res) => {
  try {
    await User.findByIdAndDelete(req.params.id);
    res.json({ message: "User deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// TOGGLE EDIT PERMISSION
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

// TOGGLE ADMIN STATUS
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

// ✅ VERIFY USER (With Smart ID Generation)
router.put("/users/:id/verify", verifyEditor, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: "User not found" });

    if (user.isVerified) {
      return res.status(400).json({ message: "User is already verified." });
    }

    // ✅ AUTO-GENERATE ID (Smart Logic)
    if (!user.alumniId) {
      // 1. Determine Year (Use User's class year, or current year)
      const targetYear = user.yearOfAttendance
        ? user.yearOfAttendance.toString()
        : new Date().getFullYear().toString();

      // 2. Find last user of THIS SPECIFIC YEAR
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

      // Sync year just in case
      if (!user.yearOfAttendance) user.yearOfAttendance = targetYear;
    }

    user.isVerified = true;
    await user.save();

    res.json({ message: "User Verified Successfully!", user });
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

    // 1. Save Event to DB
    const newEvent = new Event({
      title,
      description,
      date,
      location,
      type,
      image,
    });
    await newEvent.save();

    // ✅ 2. SEND PUSH NOTIFICATION (Updated for 2026)
    try {
      const usersWithTokens = await User.find({
        fcmToken: { $exists: true, $ne: "" },
      });

      if (usersWithTokens.length > 0) {
        console.log(`📣 Found ${usersWithTokens.length} users with tokens.`); // ✅ Log this!

        const tokens = usersWithTokens.map((u) => u.fcmToken);

        const message = {
          notification: {
            title: `New Event: ${title}`,
            body: `Join us at ${location}! ${description.substring(0, 50)}...`,
          },
          data: {
            route: "event_detail",
            eventId: newEvent._id.toString(),
          },
          tokens: tokens,
        };

        // 👇 CHANGED FROM sendMulticast TO sendEachForMulticast
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(
          `📣 Notification sent! Success: ${response.successCount}, Fail: ${response.failureCount}`
        );

        if (response.failureCount > 0) {
          const failedTokens = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              failedTokens.push(tokens[idx]);
            }
          });
          console.log("List of tokens that caused failures: " + failedTokens);
        }
      } else {
        console.log("⚠️ No users found with FCM Tokens.");
      }
    } catch (notifyError) {
      console.error("⚠️ Notification failed:", notifyError);
    }

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
    const programmes = await Programme.find().sort({ title: 1 });
    res.json(programmes);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post("/programmes", verifyEditor, async (req, res) => {
  try {
    const { title, code, description } = req.body;
    const exists = await Programme.findOne({ title });
    if (exists)
      return res.status(400).json({ message: "Programme already exists." });

    const newProg = new Programme({ title, code, description });
    await newProg.save();
    res.status(201).json({ message: "Programme added!", programme: newProg });
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

// ✅ FIXED: Missing Variable Extraction
router.put("/programmes/:id", verifyEditor, async (req, res) => {
  try {
    const { title, code, description } = req.body; // 👈 This line was missing!

    const updatedProg = await Programme.findByIdAndUpdate(
      req.params.id,
      { title, code, description },
      { new: true }
    );
    res.json({ message: "Programme updated!", programme: updatedProg });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ✅ FORCE FIX ID ROUTE
router.put("/users/:id/fix-id", verifyEditor, async (req, res) => {
  try {
    const { year } = req.body;
    const user = await User.findById(req.params.id);

    if (!user) return res.status(404).json({ message: "User not found" });

    // 1. Generate CORRECT ID
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

    // 2. Update User
    user.alumniId = newId;
    user.yearOfAttendance = targetYear;
    await user.save();

    res.json({ message: "ID Fixed Successfully!", user });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
