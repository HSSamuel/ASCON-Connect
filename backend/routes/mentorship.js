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

    // 1. Check if Mentor exists and is OPEN to mentorship
    const mentor = await User.findById(mentorId);
    if (!mentor || !mentor.isOpenToMentorship) {
      return res
        .status(400)
        .json({ message: "This user is not accepting mentorship requests." });
    }

    // 2. Check for existing request
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

    // 3. Create Request
    const newRequest = new MentorshipRequest({
      mentor: mentorId,
      mentee: req.user._id,
      pitch: pitch || "I would like to request your mentorship.",
    });

    await newRequest.save();

    // 4. Notify Mentor
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
    const { status } = req.body; // "Accepted" or "Rejected"
    const request = await MentorshipRequest.findById(req.params.id).populate(
      "mentee",
    );

    if (!request) return res.status(404).json({ message: "Request not found" });

    // Security Check: Only the designated mentor can respond
    if (request.mentor.toString() !== req.user._id) {
      return res.status(403).json({ message: "Access Denied" });
    }

    request.status = status;
    await request.save();

    if (status === "Accepted") {
      // ✅ AUTO-START CONVERSATION
      // 1. Find/Create Chat
      let conversation = await Conversation.findOne({
        members: { $all: [request.mentor, request.mentee] },
      });

      if (!conversation) {
        conversation = new Conversation({
          members: [request.mentor, request.mentee],
        });
        await conversation.save();
      }

      // 2. Send System Message
      const systemMsg = new Message({
        conversationId: conversation._id,
        sender: request.mentor, // Comes from Mentor
        text: "🎉 I have accepted your mentorship request! Let's connect.",
      });
      await systemMsg.save();

      // 3. Notify Mentee
      await sendPersonalNotification(
        request.mentee._id,
        "Mentorship Accepted! 🎉",
        "Your mentor has accepted your request. Chat now!",
        { route: "chat_screen", id: conversation._id.toString() }, // Deep link to chat
      );
    } else {
      // Notify Rejection (Optional - maybe silent rejection is better?)
      // For now, let's keep it silent or minimal to be polite.
    }

    res.json(request);
  } catch (err) {
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
// 4. CHECK STATUS (UPDATED)
// ==========================================
router.get("/status/:targetUserId", verifyToken, async (req, res) => {
  try {
    const targetId = req.params.targetUserId;
    
    const request = await MentorshipRequest.findOne({
      $or: [
        { mentor: targetId, mentee: req.user._id },
        { mentor: req.user._id, mentee: targetId }
      ]
    });

    if (!request) return res.json({ status: "None", requestId: null });
    
    // Return ID so we can cancel/end it later
    res.json({ status: request.status, requestId: request._id }); 
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 5. CANCEL REQUEST (Withdraw Pending)
// ==========================================
router.delete("/cancel/:id", verifyToken, async (req, res) => {
  try {
    const request = await MentorshipRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ message: "Request not found" });

    // Allow Sender to Cancel
    if (request.mentee.toString() !== req.user._id && request.mentor.toString() !== req.user._id) {
      return res.status(403).json({ message: "Access denied" });
    }

    await MentorshipRequest.findByIdAndDelete(req.params.id);
    res.json({ message: "Request withdrawn." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 6. END MENTORSHIP (Terminate Accepted)
// ==========================================
router.delete("/end/:id", verifyToken, async (req, res) => {
  try {
    const request = await MentorshipRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ message: "Mentorship not found" });

    // Allow either party to end it
    if (request.mentee.toString() !== req.user._id && request.mentor.toString() !== req.user._id) {
      return res.status(403).json({ message: "Access denied" });
    }

    await MentorshipRequest.findByIdAndDelete(req.params.id);
    
    // Optional: Notify the other party that it ended

    res.json({ message: "Mentorship ended." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
