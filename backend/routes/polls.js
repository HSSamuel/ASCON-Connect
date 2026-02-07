const router = require("express").Router();
const Poll = require("../models/Poll");
const Group = require("../models/Group"); // ✅ Import Group
const verifyToken = require("./verifyToken");
const { sendBroadcastNotification } = require("../utils/notificationHandler");

// GET Polls for a Specific Group
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

// POST Create Poll (Group Context)
router.post("/", verifyToken, async (req, res) => {
  try {
    const { question, options, expiresAt, groupId } = req.body;

    if (!groupId)
      return res.status(400).json({ message: "Group ID is required." });

    // 1. Check Permissions
    // User must be Admin OR have 'canCreatePolls' permission
    if (!req.user.isAdmin && !req.user.canCreatePolls) {
      return res
        .status(403)
        .json({ message: "You do not have permission to create polls." });
    }

    // 2. Check Group Membership (Optional but good practice)
    const group = await Group.findById(groupId);
    if (!group) return res.status(404).json({ message: "Group not found." });
    if (!group.members.includes(req.user._id) && !req.user.isAdmin) {
      return res
        .status(403)
        .json({ message: "You must be a member of this group." });
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
      group: groupId, // ✅ Link to Group
      votedUsers: [],
    });
    await poll.save();

    // Notify Group Members
    await sendBroadcastNotification(
      "New Group Poll! 🗳️",
      `${group.name}: ${question}`,
      { route: "group_chat", id: groupId },
    );

    res.status(201).json({ success: true, data: poll });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// PUT Vote (Remains unchanged)
router.put("/:id/vote", verifyToken, async (req, res) => {
  // ... (Same as before)
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

module.exports = router;
