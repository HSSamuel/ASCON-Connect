// backend/routes/polls.js
const router = require("express").Router();
const Poll = require("../models/Poll");
const Group = require("../models/Group");
const verifyToken = require("./verifyToken");
const { sendBroadcastNotification } = require("../utils/notificationHandler");

// ==========================================
// 1. GET ALL RELEVANT POLLS (Dashboard)
// ==========================================
router.get("/", verifyToken, async (req, res) => {
  try {
    // 1. Find groups the user belongs to
    const userGroups = await Group.find({ members: req.user._id }).select(
      "_id",
    );
    const groupIds = userGroups.map((g) => g._id);

    // 2. Fetch Active Polls (Global OR Group-specific)
    const polls = await Poll.find({
      isActive: true,
      $or: [
        { group: { $in: groupIds } }, // Polls from my groups
        { group: null }, // Global polls (no group)
      ],
    })
      .sort({ createdAt: -1 })
      .limit(20);

    res.json({ success: true, data: polls });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 2. GET POLLS FOR A SPECIFIC GROUP
// ==========================================
router.get("/group/:groupId", verifyToken, async (req, res) => {
  try {
    const polls = await Poll.find({
      group: req.params.groupId,
      isActive: true,
    }).sort({ createdAt: -1 });
    res.json({ success: true, data: polls });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 3. CREATE POLL
// ==========================================
router.post("/", verifyToken, async (req, res) => {
  try {
    const { question, options, expiresAt, groupId } = req.body;

    // 1. Permissions Check
    if (groupId) {
      const group = await Group.findById(groupId);
      if (!group) return res.status(404).json({ message: "Group not found." });

      // ✅ FIXED: Safely check if user is member OR admin
      // We use .toString() to ensure ObjectId comparison works
      const isMember = group.members.some(
        (id) => id.toString() === req.user._id,
      );
      const isAdmin = group.admins.some((id) => id.toString() === req.user._id);

      // Allow if: Member OR Group Admin OR System Admin
      if (!isMember && !isAdmin && !req.user.isAdmin) {
        return res
          .status(403)
          .json({ message: "You must be a group member to create a poll." });
      }
    } else {
      // Only Super Admins can create Global Polls (no groupId)
      if (!req.user.isAdmin && !req.user.canCreatePolls) {
        return res
          .status(403)
          .json({ message: "Unauthorized to create global polls." });
      }
    }

    const formattedOptions = options.map((opt) => ({
      text: opt,
      voteCount: 0,
    }));

    const poll = new Poll({
      question,
      options: formattedOptions,
      createdBy: req.user._id,
      expiresAt,
      group: groupId || null, // Allow null for global
      votedUsers: [],
    });
    await poll.save();

    // Broadcast Real-time event
    if (req.io) {
      req.io.emit("poll_created", { poll });
    }

    // Notify users
    if (groupId) {
      await sendBroadcastNotification("New Group Poll! 🗳️", question, {
        route: "group_chat",
        id: groupId,
      });
    } else {
      await sendBroadcastNotification("New Global Poll! 🗳️", question, {
        route: "polls",
      });
    }

    res.status(201).json({ success: true, data: poll });
  } catch (err) {
    console.error("Poll Create Error:", err);
    res.status(400).json({ message: err.message });
  }
});

// ==========================================
// 4. VOTE
// ==========================================
router.put("/:id/vote", verifyToken, async (req, res) => {
  try {
    const { optionId } = req.body;
    const userId = req.user._id;
    const poll = await Poll.findById(req.params.id);
    if (!poll) return res.status(404).json({ message: "Poll not found" });

    if (poll.votedUsers && poll.votedUsers.includes(userId)) {
      return res.status(400).json({ message: "You have already voted." });
    }

    const option = poll.options.id(optionId);
    if (!option) return res.status(400).json({ message: "Invalid option" });

    option.voteCount = (option.voteCount || 0) + 1;
    if (!poll.votedUsers) poll.votedUsers = [];
    poll.votedUsers.push(userId);

    await poll.save();

    if (req.io) {
      req.io.emit("poll_updated", { pollId: poll._id, updatedPoll: poll });
    }
    res.json({ success: true, message: "Vote recorded", data: poll });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 5. DELETE POLL
// ==========================================
router.delete("/:id", verifyToken, async (req, res) => {
  try {
    const poll = await Poll.findById(req.params.id);
    if (!poll) return res.status(404).json({ message: "Poll not found" });

    // Check ownership or admin
    if (poll.createdBy.toString() !== req.user._id && !req.user.isAdmin) {
      return res
        .status(403)
        .json({ message: "Unauthorized to delete this poll." });
    }

    await Poll.findByIdAndDelete(req.params.id);

    // Notify clients to remove it locally
    if (req.io) req.io.emit("poll_deleted", { pollId: req.params.id });

    res.json({ success: true, message: "Poll deleted" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 6. EDIT POLL (Question Only)
// ==========================================
router.put("/:id", verifyToken, async (req, res) => {
  try {
    const { question } = req.body;
    const poll = await Poll.findById(req.params.id);
    if (!poll) return res.status(404).json({ message: "Poll not found" });

    // Check ownership or admin
    if (poll.createdBy.toString() !== req.user._id && !req.user.isAdmin) {
      return res
        .status(403)
        .json({ message: "Unauthorized to edit this poll." });
    }

    poll.question = question || poll.question;
    await poll.save();

    if (req.io)
      req.io.emit("poll_updated", { pollId: poll._id, updatedPoll: poll });

    res.json({ success: true, message: "Poll updated", data: poll });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
