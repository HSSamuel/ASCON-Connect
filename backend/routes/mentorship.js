const router = require("express").Router();
const MentorshipRequest = require("../models/MentorshipRequest");
const User = require("../models/User");
const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const verifyToken = require("./verifyToken");
const { sendPersonalNotification } = require("../utils/notificationHandler");

// ==========================================
// 1. SEND A REQUEST (Mentee -> Mentor)
// ==========================================
router.post("/request", verifyToken, async (req, res) => {
  try {
    const { mentorId, pitch } = req.body;

    if (mentorId === req.user._id) {
      return res.status(400).json({ message: "You cannot mentor yourself." });
    }

    const mentor = await User.findById(mentorId);
    if (!mentor || !mentor.isOpenToMentorship) {
      return res
        .status(400)
        .json({ message: "This user is not accepting mentorship requests." });
    }

    const existing = await MentorshipRequest.findOne({
      mentor: mentorId,
      mentee: req.user._id,
    });

    if (existing) {
      if (existing.status === "Pending")
        return res.status(400).json({ message: "Request already pending." });
      if (existing.status === "Accepted")
        return res
          .status(400)
          .json({ message: "You are already mentoring this user." });
      if (existing.status === "Rejected")
        return res
          .status(400)
          .json({ message: "Your previous request was declined." });
    }

    const newRequest = new MentorshipRequest({
      mentor: mentorId,
      mentee: req.user._id,
      pitch: pitch || "I would like to request your mentorship.",
    });

    await newRequest.save();

    // ✅ NOTIFY MENTOR (ALWAYS)
    await sendPersonalNotification(
      mentorId,
      "New Mentorship Request 🎓",
      "Someone has requested your mentorship. Tap to review.",
      { route: "mentorship_requests" },
    );

    res.status(201).json(newRequest);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 2. RESPOND TO REQUEST (Mentor -> Mentee)
// ==========================================
router.put("/respond/:id", verifyToken, async (req, res) => {
  try {
    const { status } = req.body;
    const request = await MentorshipRequest.findById(req.params.id).populate(
      "mentee",
    );

    if (!request) return res.status(404).json({ message: "Request not found" });

    if (request.mentor.toString() !== req.user._id) {
      return res.status(403).json({ message: "Access Denied" });
    }

    request.status = status;
    await request.save();

    if (status === "Accepted") {
      // 1. Find/Create Chat
      let conversation = await Conversation.findOne({
        participants: { $all: [request.mentor, request.mentee._id] }, // ✅ Fixed field name to 'participants' to match schema
      });

      if (!conversation) {
        conversation = new Conversation({
          participants: [request.mentor, request.mentee._id],
        });
        await conversation.save();
      }

      // 2. Create System Message
      const systemMsg = new Message({
        conversationId: conversation._id,
        sender: request.mentor,
        text: "🎉 I have accepted your mentorship request! Let's connect.",
        isRead: false,
      });
      await systemMsg.save();

      // 3. Update Conversation Last Message
      conversation.lastMessage = "🎉 Mentorship Accepted";
      conversation.lastMessageAt = Date.now();
      await conversation.save();

      // 4. ✅ EMIT SOCKET EVENT (So chat appears instantly for Mentee)
      if (req.io) {
        req.io.to(request.mentee._id.toString()).emit("new_message", {
          message: systemMsg,
          conversationId: conversation._id,
        });
      }

      // 5. ✅ NOTIFY MENTEE (ALWAYS)
      await sendPersonalNotification(
        request.mentee._id.toString(),
        "Mentorship Accepted! 🎉",
        "Your mentor has accepted your request. Chat now!",
        { route: "chat_screen", id: conversation._id.toString() },
      );
    }

    res.json(request);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 3. GET MY DASHBOARD (Both Roles)
// ==========================================
router.get("/dashboard", verifyToken, async (req, res) => {
  try {
    const myId = req.user._id;

    // 1. Requests I SENT (As a Mentee)
    const sentRequests = await MentorshipRequest.find({ mentee: myId })
      .populate("mentor", "fullName profilePicture jobTitle organization")
      .sort({ createdAt: -1 });

    // 2. Requests I RECEIVED (As a Mentor)
    const receivedRequests = await MentorshipRequest.find({
      mentor: myId,
      status: "Pending",
    })
      .populate("mentee", "fullName profilePicture jobTitle organization")
      .sort({ createdAt: -1 });

    // 3. My Active Mentors (Accepted)
    const myMentors = await MentorshipRequest.find({
      mentee: myId,
      status: "Accepted",
    }).populate("mentor", "fullName profilePicture");

    // 4. My Active Mentees (Accepted)
    const myMentees = await MentorshipRequest.find({
      mentor: myId,
      status: "Accepted",
    }).populate("mentee", "fullName profilePicture");

    res.json({
      sent: sentRequests,
      received: receivedRequests,
      activeMentors: myMentors,
      activeMentees: myMentees,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 4. CHECK STATUS
// ==========================================
router.get("/status/:targetUserId", verifyToken, async (req, res) => {
  try {
    const targetId = req.params.targetUserId;

    const request = await MentorshipRequest.findOne({
      $or: [
        { mentor: targetId, mentee: req.user._id },
        { mentor: req.user._id, mentee: targetId },
      ],
    });

    if (!request) return res.json({ status: "None", requestId: null });

    res.json({ status: request.status, requestId: request._id });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 5. CANCEL REQUEST
// ==========================================
router.delete("/cancel/:id", verifyToken, async (req, res) => {
  try {
    const request = await MentorshipRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ message: "Request not found" });

    if (
      request.mentee.toString() !== req.user._id &&
      request.mentor.toString() !== req.user._id
    ) {
      return res.status(403).json({ message: "Access denied" });
    }

    await MentorshipRequest.findByIdAndDelete(req.params.id);
    res.json({ message: "Request withdrawn." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 6. END MENTORSHIP
// ==========================================
router.delete("/end/:id", verifyToken, async (req, res) => {
  try {
    const request = await MentorshipRequest.findById(req.params.id);
    if (!request)
      return res.status(404).json({ message: "Mentorship not found" });

    if (
      request.mentee.toString() !== req.user._id &&
      request.mentor.toString() !== req.user._id
    ) {
      return res.status(403).json({ message: "Access denied" });
    }

    await MentorshipRequest.findByIdAndDelete(req.params.id);
    res.json({ message: "Mentorship ended." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
