const router = require("express").Router();
const Event = require("../models/Event");

// @route   GET /api/events
// @desc    Get all events (Sorted by closest date)
router.get("/", async (req, res) => {
  try {
    // Sort by Date (descending) so newest/future events are top
    const events = await Event.find().sort({ date: 1 });
    res.json(events);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// @route   POST /api/events
// @desc    Create a new Event
router.post("/", async (req, res) => {
  const event = new Event({
    title: req.body.title,
    description: req.body.description,
    date: req.body.date,
    location: req.body.location,
    type: req.body.type,
  });

  try {
    const savedEvent = await event.save();
    res.status(201).json(savedEvent);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// @route   DELETE /api/events/:id
// @desc    Delete an event by ID (✅ NEW ROUTE)
router.delete("/:id", async (req, res) => {
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
