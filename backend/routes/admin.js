const router = require("express").Router();
// ✅ NEW: Import 3 schemas instead of User
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");

const Event = require("../models/Event");
const Programme = require("../models/Programme");
const ProgrammeInterest = require("../models/ProgrammeInterest");
const EventRegistration = require("../models/EventRegistration");
const Facility = require("../models/Facility");
const jwt = require("jsonwebtoken");
const Joi = require("joi");

const {
  sendBroadcastNotification,
  sendPersonalNotification,
} = require("../utils/notificationHandler");

// ==========================================
// 🛡️ MIDDLEWARE
// ==========================================
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
// 🛡️ VALIDATION SCHEMAS
// ==========================================
const eventSchema = Joi.object({
  title: Joi.string().min(5).required(),
  description: Joi.string().min(10).required(),
  date: Joi.date().optional(),
  time: Joi.string().optional().allow(""),
  location: Joi.string().optional().allow(""),
  type: Joi.string()
    .valid(
      "News",
      "Event",
      "Reunion",
      "Webinar",
      "Seminar",
      "Conference",
      "Workshop",
      "Symposium",
      "AGM",
      "Induction",
    )
    .default("News"),
  image: Joi.string().optional().allow(""),
});

const programmeSchema = Joi.object({
  title: Joi.string().min(3).required(),
  description: Joi.string().min(5).required(),
  location: Joi.string().required(),
  duration: Joi.string().required(),
  fee: Joi.string().optional().allow(""),
  image: Joi.string().optional().allow(""),
});

// ==========================================
// 📊 DASHBOARD STATS
// ==========================================
router.get("/stats", verifyAdmin, async (req, res) => {
  try {
    const [
      userCount,
      eventCount,
      progCount,
      progInterestCount,
      eventRegCount,
      facilityCount,
    ] = await Promise.all([
      UserAuth.countDocuments(), // ✅ Count Auth Docs for total users
      Event.countDocuments(),
      Programme.countDocuments(),
      ProgrammeInterest.countDocuments(),
      EventRegistration.countDocuments(),
      Facility.countDocuments(),
    ]);

    res.json({
      users: userCount,
      events: eventCount,
      programmes: progCount,
      totalRegistrations: progInterestCount + eventRegCount,
      facilities: facilityCount,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 1. USER MANAGEMENT (Aggregated)
// ==========================================
router.get("/users", verifyAdmin, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || "";
    const skip = (page - 1) * limit;

    let matchQuery = {};
    if (search) {
      matchQuery = {
        $or: [
          { "profile.fullName": { $regex: search, $options: "i" } },
          { email: { $regex: search, $options: "i" } },
          { "profile.alumniId": { $regex: search, $options: "i" } },
          { "profile.programmeTitle": { $regex: search, $options: "i" } },
        ],
      };
    }

    // ✅ NEW: Aggregate 3 collections dynamically for the Admin List
    const users = await UserAuth.aggregate([
      {
        $lookup: {
          from: "userprofiles",
          localField: "_id",
          foreignField: "userId",
          as: "profile",
        },
      },
      { $unwind: "$profile" },
      {
        $lookup: {
          from: "usersettings",
          localField: "_id",
          foreignField: "userId",
          as: "settings",
        },
      },
      { $unwind: "$settings" },
      { $match: matchQuery },
      { $sort: { isAdmin: -1, createdAt: -1 } },
      { $skip: skip },
      { $limit: limit },
      {
        $project: {
          password: 0, // Exclude password
          "profile._id": 0,
          "settings._id": 0,
        },
      },
      // Flatten the result so the frontend Dashboard works without changes
      {
        $addFields: {
          fullName: "$profile.fullName",
          alumniId: "$profile.alumniId",
          programmeTitle: "$profile.programmeTitle",
          yearOfAttendance: "$profile.yearOfAttendance",
          profilePicture: "$profile.profilePicture",
        },
      },
    ]);

    const totalPipeline = await UserAuth.aggregate([
      {
        $lookup: {
          from: "userprofiles",
          localField: "_id",
          foreignField: "userId",
          as: "profile",
        },
      },
      { $unwind: "$profile" },
      { $match: matchQuery },
      { $count: "total" },
    ]);
    const total = totalPipeline.length > 0 ? totalPipeline[0].total : 0;

    res.json({ users, total, page, pages: Math.ceil(total / limit) });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ✅ DELETE CASCADES ACROSS ALL 3 TABLES
router.delete("/users/:id", verifyEditor, async (req, res) => {
  try {
    await Promise.all([
      UserAuth.findByIdAndDelete(req.params.id),
      UserProfile.findOneAndDelete({ userId: req.params.id }),
      UserSettings.findOneAndDelete({ userId: req.params.id }),
    ]);
    res.json({ message: "User deleted from all tables." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/users/:id/toggle-edit", verifyEditor, async (req, res) => {
  try {
    const userAuth = await UserAuth.findById(req.params.id);
    userAuth.canEdit = !userAuth.canEdit;
    await userAuth.save();
    res.json({
      message: `Edit permission ${userAuth.canEdit ? "GRANTED" : "REVOKED"}`,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/users/:id/toggle-admin", verifyEditor, async (req, res) => {
  try {
    const userAuth = await UserAuth.findById(req.params.id);
    userAuth.isAdmin = !userAuth.isAdmin;
    if (!userAuth.isAdmin) userAuth.canEdit = false;
    await userAuth.save();
    res.json({
      message: `Admin Access ${userAuth.isAdmin ? "GRANTED" : "REVOKED"}`,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/users/:id/verify", verifyEditor, async (req, res) => {
  try {
    const userAuth = await UserAuth.findById(req.params.id);
    const userProfile = await UserProfile.findOne({ userId: req.params.id });

    if (!userAuth || !userProfile)
      return res.status(404).json({ message: "User not found" });
    if (userAuth.isVerified)
      return res.status(400).json({ message: "User is already verified." });

    if (!userProfile.alumniId) {
      const targetYear = userProfile.yearOfAttendance
        ? userProfile.yearOfAttendance.toString()
        : new Date().getFullYear().toString();
      const regex = new RegExp(`ASC/${targetYear}/`);
      const lastUser = await UserProfile.findOne({
        alumniId: { $regex: regex },
      }).sort({ _id: -1 });

      let nextNum = 1;
      if (lastUser && lastUser.alumniId) {
        const parts = lastUser.alumniId.split("/");
        const lastNum = parseInt(parts[parts.length - 1]);
        if (!isNaN(lastNum)) nextNum = lastNum + 1;
      }
      const paddedNum = nextNum.toString().padStart(4, "0");
      userProfile.alumniId = `ASC/${targetYear}/${paddedNum}`;
      if (!userProfile.yearOfAttendance)
        userProfile.yearOfAttendance = targetYear;
    }

    userAuth.isVerified = true;
    await Promise.all([userAuth.save(), userProfile.save()]);

    await sendPersonalNotification(
      userAuth._id,
      "Account Verified! 🎉",
      "Your ASCON Alumni account has been approved. You can now access your Digital ID.",
    );

    res.json({ message: "User Verified & Notified!" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 2. EVENT MANAGEMENT (Unchanged)
// ==========================================

router.post("/events", verifyEditor, async (req, res) => {
  const { error } = eventSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const { title, description, date, time, type, image, location } = req.body;
    const newEvent = new Event({
      title,
      description,
      date,
      time,
      type,
      image,
      location,
    });
    await newEvent.save();

    await sendBroadcastNotification(
      title,
      `${description.substring(0, 60)}...`,
      {
        route: "event_detail",
        id: newEvent._id.toString(),
      },
    );

    res
      .status(201)
      .json({ message: "Event created & Notified!", event: newEvent });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/events/:id", verifyEditor, async (req, res) => {
  const { error } = eventSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const updatedEvent = await Event.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true },
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
// 3. PROGRAMME MANAGEMENT (Unchanged)
// ==========================================

router.get("/programmes", async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || "";
    let query = search
      ? { $or: [{ title: { $regex: search, $options: "i" } }] }
      : {};

    const skip = (page - 1) * limit;
    const programmes = await Programme.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);
    const total = await Programme.countDocuments(query);

    res.json({ programmes, total, page, pages: Math.ceil(total / limit) });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.get("/programmes/:id", async (req, res) => {
  try {
    const programme = await Programme.findById(req.params.id);
    if (!programme)
      return res.status(404).json({ message: "Programme not found" });
    res.json({ data: programme });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post("/programmes", verifyEditor, async (req, res) => {
  const { error } = programmeSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const { title, description, location, duration, fee, image } = req.body;
    const exists = await Programme.findOne({ title });
    if (exists)
      return res.status(400).json({ message: "Programme already exists." });

    const newProg = new Programme({
      title,
      description,
      location,
      duration,
      fee,
      image,
    });
    await newProg.save();

    await sendBroadcastNotification(
      title,
      `${description.substring(0, 60)}...`,
      {
        route: "programme_detail",
        id: newProg._id.toString(),
      },
    );

    res
      .status(201)
      .json({ message: "Programme added & Notified!", programme: newProg });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.put("/programmes/:id", verifyEditor, async (req, res) => {
  const { error } = programmeSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const updatedProg = await Programme.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true },
    );
    res.json({ message: "Programme updated!", programme: updatedProg });
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

// ✅ FIX ID ON PROFILE TABLE
router.put("/users/:id/fix-id", verifyEditor, async (req, res) => {
  try {
    const { year } = req.body;
    const profile = await UserProfile.findOne({ userId: req.params.id });
    if (!profile)
      return res.status(404).json({ message: "User Profile not found" });

    const targetYear = year
      ? year.toString()
      : new Date().getFullYear().toString();
    const regex = new RegExp(`ASC/${targetYear}/`);
    const lastUser = await UserProfile.findOne({
      alumniId: { $regex: regex },
    }).sort({ _id: -1 });

    let nextNum = 1;
    if (lastUser && lastUser.alumniId) {
      const parts = lastUser.alumniId.split("/");
      const lastNum = parseInt(parts[parts.length - 1]);
      if (!isNaN(lastNum)) nextNum = lastNum + 1;
    }
    const paddedNum = nextNum.toString().padStart(4, "0");

    profile.alumniId = `ASC/${targetYear}/${paddedNum}`;
    profile.yearOfAttendance = targetYear;
    await profile.save();

    res.json({ message: "ID Fixed Successfully!" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
