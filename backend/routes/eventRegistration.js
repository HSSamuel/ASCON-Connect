const router = require("express").Router();
const EventRegistration = require("../models/EventRegistration");

// ✅ CRITICAL FIX: Import the verification middleware
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");

// @route   POST /api/event-registration
// @desc    Register for an event
router.post("/", async (req, res) => {
  try {
    const newReg = new EventRegistration(req.body);
    await newReg.save();
    res.status(201).json({
      success: true,
      message: "Registration successful! We will contact you shortly.",
    });
  } catch (err) {
    res
      .status(500)
      .json({ success: false, message: "Server Error: Could not register." });
  }
});

// @route   GET /api/event-registration
// @desc    Get all event registrations (For Admin Panel)
router.get("/", async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const regs = await EventRegistration.find()
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await EventRegistration.countDocuments();

    res.json({
      registrations: regs,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error." });
  }
});

// @route   DELETE /api/event-registration/:id
// @desc    Delete an event registration (Admin Only)
router.delete("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const deleted = await EventRegistration.findByIdAndDelete(req.params.id);
    if (!deleted)
      return res.status(404).json({ message: "Registration not found" });

    res.json({ message: "Registration deleted successfully." });
  } catch (err) {
    res.status(500).json({ message: "Server error." });
  }
});

module.exports = router;
