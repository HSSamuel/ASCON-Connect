const router = require("express").Router();
const Event = require("../models/Event");
const Joi = require("joi");
const { sendBroadcastNotification } = require("../utils/notificationHandler");
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");

// ==========================================
// 🛡️ VALIDATION SCHEMA
// ==========================================
const eventSchema = Joi.object({
  title: Joi.string().min(5).required(),
  description: Joi.string().min(10).required(),
  date: Joi.date().optional(),
  // ✅ NEW: Allow location string (optional, defaults handled in model)
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
      "Induction"
    )
    .default("News"),
  image: Joi.string().optional().allow(""),
});

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
// @desc    Create a new Event (Secured with Joi)
router.post("/", verifyToken, verifyAdmin, async (req, res) => {
  // ✅ Validate Input
  const { error } = eventSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const event = new Event({
      title: req.body.title,
      description: req.body.description,
      date: req.body.date,
      // ✅ NEW: Save location from request
      location: req.body.location,
      type: req.body.type,
      image: req.body.image,
    });

    const savedEvent = await event.save();

    // ✅ Send Notification
    try {
      await sendBroadcastNotification(
        `New ${savedEvent.type}: ${savedEvent.title}`,
        `${savedEvent.description.substring(0, 50)}...`,
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

// @route   GET /api/events/:id
// @desc    Get single event
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
