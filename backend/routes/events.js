const router = require("express").Router();
const Event = require("../models/Event");
// ✅ FIX: Correct path and filename
const { sendBroadcastNotification } = require("../utils/notificationHandler");
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");

// @route   GET /api/events
// @desc    Get all events (Sorted by Newest First)
router.get("/", async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const events = await Event.find()
      .sort({ date: -1 })
      .skip(skip)
      .limit(limit);

    const total = await Event.countDocuments();

    res.json({
      events,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// @route   POST /api/events
// @desc    Create a new Event (This endpoint is likely redundant if you use admin.js, but we fix it anyway)
router.post("/", verifyToken, verifyAdmin, async (req, res) => {
  const event = new Event({
    title: req.body.title,
    description: req.body.description,
    date: req.body.date,
    location: req.body.location,
    type: req.body.type,
    image: req.body.image,
  });

  try {
    const savedEvent = await event.save();

    // ✅ OPTIONAL: Send Notification here too (just in case this route is used instead of admin.js)
    try {
      await sendBroadcastNotification(
        `New ${savedEvent.type}: ${savedEvent.title}`,
        `Join us at ${savedEvent.location}!`,
        { route: "event_detail", id: savedEvent._id.toString() }
      );
    } catch (notifyErr) {
      console.error("Notification failed inside events.js:", notifyErr);
    }

    res.status(201).json(savedEvent);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// @route   DELETE /api/events/:id
// @desc    Delete an event by ID
router.delete("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const removedEvent = await Event.findByIdAndDelete(req.params.id);
    if (!removedEvent) {
      return res.status(404).json({ message: "Event not found" });
    }
    res.json({ message: "Event deleted successfully" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ✅ ADD THIS TO backend/routes/events.js if missing
router.get("/:id", async (req, res) => {
  try {
    const event = await Event.findById(req.params.id);
    if (!event) return res.status(404).json({ message: "Event not found" });
    res.json({ data: event });
  } catch (err) {
    res.status(500).json({ message: "Server error" });
  }
});

module.exports = router;
