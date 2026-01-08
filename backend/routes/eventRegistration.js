const router = require("express").Router();
const EventRegistration = require("../models/EventRegistration");
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");

// ==========================================
// 1. POST: Register for an event
// ==========================================
// @route   POST /api/event-registration
router.post("/", async (req, res) => {
  try {
    // 1. Log the incoming data to help debugging
    console.log("Incoming Registration Data:", req.body);

    const { eventId, fullName, email, phone, userId } = req.body;

    // 2. Simple Validation Check
    if (!eventId || !fullName || !email || !phone) {
      return res.status(400).json({
        success: false,
        message: "Missing required fields: Event ID, Name, Email, or Phone.",
      });
    }

    // ✅ 3. DUPLICATE CHECK
    // Prevents the same email from registering for the same event twice
    const alreadyRegistered = await EventRegistration.findOne({
      eventId,
      email,
    });
    if (alreadyRegistered) {
      return res.status(400).json({
        success: false,
        message: "You are already registered for this event.",
      });
    }

    // ✅ 4. USER ID TYPE SAFETY
    // If Flutter sends an empty string for userId, we convert it to null
    // This prevents MongoDB from crashing when trying to save a non-ObjectId string.
    const finalData = {
      ...req.body,
      userId: userId && userId.length > 5 ? userId : null,
      email: email.toLowerCase().trim(),
    };

    // 5. Save to Database
    const newReg = new EventRegistration(finalData);
    await newReg.save();

    res.status(201).json({
      success: true,
      message: "Registration successful! We will contact you shortly.",
    });
  } catch (err) {
    console.error("EVENT_REG_ERROR:", err);
    res.status(500).json({
      success: false,
      message: "Server Error: " + err.message,
    });
  }
});

// ==========================================
// 2. GET: View all registrations (Admin only)
// ==========================================
// @route   GET /api/event-registration
router.get("/", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    // ✅ POPULATE userId to see official Alumni Details automatically
    const regs = await EventRegistration.find()
      .populate("userId", "fullName alumniId profilePicture")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await EventRegistration.countDocuments();

    // ✅ FIX: Ensure virtuals like 'id' are included in the response
    const formattedRegs = regs.map((reg) => reg.toJSON());

    res.json({
      success: true,
      registrations: formattedRegs,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error("GET_REGS_ERROR:", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

// ==========================================
// 3. DELETE: Remove a registration (Admin only)
// ==========================================
// @route   DELETE /api/event-registration/:id
router.delete("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const deleted = await EventRegistration.findByIdAndDelete(req.params.id);
    if (!deleted) {
      return res
        .status(404)
        .json({ success: false, message: "Registration not found" });
    }

    res.json({ success: true, message: "Registration deleted successfully." });
  } catch (err) {
    console.error("DELETE_REG_ERROR:", err);
    res.status(500).json({ success: false, message: "Server error." });
  }
});

module.exports = router;
