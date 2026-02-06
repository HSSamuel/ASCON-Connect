const router = require("express").Router();
const Poll = require("../models/Poll");
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");

// GET Active Polls
router.get("/", verifyToken, async (req, res) => {
  try {
    const polls = await Poll.find({ isActive: true }).sort({ createdAt: -1 });
    res.json({ success: true, data: polls });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST Create Poll (Admin Only)
router.post("/", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const { question, options, expiresAt } = req.body;
    // Transform simple strings to object structure
    const formattedOptions = options.map((opt) => ({ text: opt, votes: [] }));

    const poll = new Poll({
      question,
      options: formattedOptions,
      createdBy: req.user._id,
      expiresAt,
    });
    await poll.save();
    res.status(201).json({ success: true, data: poll });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// PUT Vote
router.put("/:id/vote", verifyToken, async (req, res) => {
  try {
    const { optionId } = req.body;
    const poll = await Poll.findById(req.params.id);

    if (!poll) return res.status(404).json({ message: "Poll not found" });

    // Remove previous vote if exists
    poll.options.forEach((opt) => {
      opt.votes = opt.votes.filter((v) => v.toString() !== req.user._id);
    });

    // Add new vote
    const option = poll.options.id(optionId);
    if (option) {
      option.votes.push(req.user._id);
      await poll.save();
      res.json({ success: true, message: "Vote recorded", data: poll });
    } else {
      res.status(400).json({ message: "Invalid option" });
    }
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
