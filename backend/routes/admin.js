const router = require("express").Router();
const User = require("../models/User");
const Event = require("../models/Event");
const Programme = require("../models/Programme");
const jwt = require("jsonwebtoken");

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

    // ✅ CHECK: Is this admin allowed to edit?
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

// GET ALL USERS (Read-Only: verifyAdmin is enough)
router.get("/users", verifyAdmin, async (req, res) => {
  try {
    const users = await User.find().select("-password").sort({ createdAt: -1 });
    res.json(users);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// VERIFY USER (Write Action: Needs verifyEditor)
router.put("/users/:id/verify", verifyEditor, async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { isVerified: true },
      { new: true }
    );
    res.json({ message: "User verified successfully!", user });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// DELETE USER (Write Action: Needs verifyEditor)
router.delete("/users/:id", verifyEditor, async (req, res) => {
  try {
    await User.findByIdAndDelete(req.params.id);
    res.json({ message: "User deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ✅ NEW: TOGGLE EDIT PERMISSION (Super Admin Action)
// Allows an Editor to give edit rights to another admin
router.put("/users/:id/toggle-edit", verifyEditor, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    user.canEdit = !user.canEdit; // Toggle
    await user.save();
    res.json({
      message: `Edit permission ${user.canEdit ? "GRANTED" : "REVOKED"}`,
      user,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// TOGGLE ADMIN STATUS (Super Admin Only)
router.put("/users/:id/toggle-admin", verifyEditor, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    
    // Safety: Prevent removing admin rights from yourself if you are the only one!
    // (Optional logic, but good practice)
    
    user.isAdmin = !user.isAdmin; // Switch between true/false
    
    // If we demote an Admin, we should also remove their Edit rights to be safe
    if (!user.isAdmin) {
      user.canEdit = false;
    }

    await user.save();
    res.json({ message: `Admin Access ${user.isAdmin ? "GRANTED" : "REVOKED"}`, user });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 2. EVENT MANAGEMENT
// ==========================================

// CREATE EVENT (Write Action: Needs verifyEditor)
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
    res.status(201).json({ message: "Event created!", event: newEvent });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// UPDATE EVENT (Write Action: Needs verifyEditor)
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

// DELETE EVENT (Write Action: Needs verifyEditor)
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

// GET PROGRAMMES (Public)
router.get("/programmes", async (req, res) => {
  try {
    const programmes = await Programme.find().sort({ title: 1 });
    res.json(programmes);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ADD PROGRAMME (Write Action: Needs verifyEditor)
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

// DELETE PROGRAMME (Write Action: Needs verifyEditor)
router.delete("/programmes/:id", verifyEditor, async (req, res) => {
  try {
    await Programme.findByIdAndDelete(req.params.id);
    res.json({ message: "Programme deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// UPDATE PROGRAMME (Write Action: Needs verifyEditor)
router.put("/programmes/:id", verifyEditor, async (req, res) => {
  try {
    const { title, code, description } = req.body;
    
    // Find the programme by ID and update it
    const updatedProg = await Programme.findByIdAndUpdate(
      req.params.id,
      { title, code, description },
      { new: true } // This ensures we get back the *new* updated version
    );

    res.json({ message: "Programme updated!", programme: updatedProg });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
