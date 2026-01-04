const router = require("express").Router();
const Event = require("../models/Event");
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");

// @route   GET /api/events
// @desc    Get all events (Sorted by closest date)
router.get("/", async (req, res) => {
  try {
    // Sort by Date (ascending/1 usually means oldest first, -1 is newest first)
    // Depending on your need: 1 = Jan, Feb... | -1 = Dec, Nov...
    const events = await Event.find().sort({ date: 1 });
    res.json(events);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// @route   POST /api/events
// @desc    Create a new Event
router.post("/", verifyToken, verifyAdmin, async (req, res) => {
  const event = new Event({
    title: req.body.title,
    description: req.body.description,
    date: req.body.date,
    location: req.body.location,
    type: req.body.type,
    // ✅ NEW ADDITION: Make sure to capture the image from the request!
    image: req.body.image 
  });

  try {
    const savedEvent = await event.save();
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

module.exports = router;