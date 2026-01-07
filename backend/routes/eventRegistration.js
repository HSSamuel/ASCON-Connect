const router = require("express").Router();
const EventRegistration = require("../models/EventRegistration");

// @route   POST /api/event-registration
// @desc    Register for an event
router.post("/", async (req, res) => {
  try {
    const newReg = new EventRegistration(req.body);
    await newReg.save();
    res
      .status(201)
      .json({
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
    // Sort by Newest First (-1)
    const regs = await EventRegistration.find().sort({ createdAt: -1 });
    res.json(regs);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error." });
  }
});

module.exports = router;
