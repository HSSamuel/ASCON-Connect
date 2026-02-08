// backend/routes/groups.js
const router = require("express").Router();
const Group = require("../models/Group");
const UserProfile = require("../models/UserProfile");
const Conversation = require("../models/Conversation"); // ✅ Added Missing Import
const verifyToken = require("./verifyToken");

// Cloudinary & Multer Config for Group Icons
const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const cloudinary = require("../config/cloudinary").cloudinary;

const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "ascon_groups",
    allowed_formats: ["jpg", "png", "jpeg"],
  },
});
const upload = multer({ storage: storage });

// ==========================================
// 1. GET GROUP INFO (Members & Admins)
// ==========================================
router.get("/:groupId/info", verifyToken, async (req, res) => {
  try {
    const group = await Group.findById(req.params.groupId).lean();

    if (!group) return res.status(404).json({ message: "Group not found" });

    // Fetch Profile Details for all members
    const memberProfiles = await UserProfile.find({
      userId: { $in: group.members },
    }).select("userId fullName profilePicture jobTitle alumniId");

    // Enrich with 'isAdmin' flag
    const enrichedMembers = memberProfiles.map((p) => ({
      _id: p.userId,
      fullName: p.fullName,
      profilePicture: p.profilePicture,
      jobTitle: p.jobTitle,
      alumniId: p.alumniId,
      isAdmin: (group.admins || [])
        .map((id) => id.toString())
        .includes(p.userId.toString()),
    }));

    res.json({
      success: true,
      data: {
        ...group,
        members: enrichedMembers,
        // Return raw admin IDs for easy checking on frontend
        admins: group.admins || [],
        isCurrentUserAdmin: (group.admins || [])
          .map((id) => id.toString())
          .includes(req.user._id),
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 2. UPDATE GROUP ICON (Admin Only)
// ==========================================
router.put(
  "/:groupId/icon",
  verifyToken,
  upload.single("icon"),
  async (req, res) => {
    try {
      const group = await Group.findById(req.params.groupId);
      if (!group) return res.status(404).json({ message: "Group not found" });

      // Check Admin Privileges
      if (!group.admins.includes(req.user._id)) {
        return res
          .status(403)
          .json({ message: "Only Admins can change the icon." });
      }

      if (req.file) {
        group.icon = req.file.path;
        await group.save();
        res.json({
          success: true,
          message: "Group icon updated!",
          icon: group.icon,
        });
      } else {
        res.status(400).json({ message: "No image uploaded." });
      }
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  },
);

// ==========================================
// 3. GET MY GROUPS
// ==========================================
router.get("/my-groups", verifyToken, async (req, res) => {
  try {
    const groups = await Group.find({ members: req.user._id })
      .select("name type icon members")
      .lean();

    const formattedGroups = groups.map((g) => ({
      _id: g._id,
      name: g.name,
      type: g.type,
      icon: g.icon,
      memberCount: g.members.length,
    }));

    res.json({ success: true, data: formattedGroups });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 4. TOGGLE GROUP ADMIN STATUS
// ==========================================
router.put("/:groupId/toggle-admin", verifyToken, async (req, res) => {
  try {
    const { targetUserId } = req.body;
    const group = await Group.findById(req.params.groupId);

    if (!group) return res.status(404).json({ message: "Group not found" });
    if (!group.admins) group.admins = [];

    const amIAdmin = group.admins.includes(req.user._id);
    if (!amIAdmin && group.admins.length > 0) {
      return res
        .status(403)
        .json({ message: "Only Group Admins can do this." });
    }

    const index = group.admins.indexOf(targetUserId);
    if (index === -1) {
      group.admins.push(targetUserId);
    } else {
      group.admins.splice(index, 1);
    }

    await group.save();
    res.json({ success: true, message: "Admin role updated successfully." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 5. REMOVE MEMBER (With Socket Eviction)
// ==========================================
router.put("/:groupId/remove-member", verifyToken, async (req, res) => {
  try {
    const { targetUserId } = req.body;
    const group = await Group.findById(req.params.groupId);

    if (!group) return res.status(404).json({ message: "Group not found" });
    if (!group.admins) group.admins = [];

    if (!group.admins.includes(req.user._id)) {
      return res.status(403).json({ message: "Only Group Admins can remove members." });
    }

    // 1. Remove from Group Model
    group.members = group.members.filter((id) => id.toString() !== targetUserId);
    group.admins = group.admins.filter((id) => id.toString() !== targetUserId);
    await group.save();

    // 2. Remove from Chat Conversation (Database Level)
    await Conversation.updateOne(
      { groupId: req.params.groupId },
      { $pull: { participants: targetUserId } }
    );

    // 3. ✅ REAL-TIME EVICTION: Tell the specific user they are removed
    // This requires the client to listen for 'removed_from_group' and refresh/navigate away
    if (req.io) {
        req.io.to(targetUserId).emit("removed_from_group", { 
            groupId: req.params.groupId,
            groupName: group.name 
        });
    }

    res.json({ success: true, message: "User removed from group." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 6. GET GROUP NOTICES (Notice Board)
// ==========================================
router.get("/:groupId/notices", verifyToken, async (req, res) => {
  try {
    // Only fetch the notices array to be lightweight
    const group = await Group.findById(req.params.groupId)
      .select("notices")
      // Optional: Populate who posted it if you want names
      .populate("notices.postedBy", "email");

    if (!group) return res.status(404).json({ message: "Group not found" });

    // Sort notices: Newest first
    const sortedNotices = group.notices.sort(
      (a, b) => b.createdAt - a.createdAt,
    );

    res.json({ success: true, data: sortedNotices });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 7. POST NEW NOTICE (Admin Only)
// ==========================================
router.post("/:groupId/notices", verifyToken, async (req, res) => {
  try {
    const { title, content } = req.body;
    const group = await Group.findById(req.params.groupId);

    if (!group) return res.status(404).json({ message: "Group not found" });

    // ✅ STRICT ADMIN CHECK
    if (!group.admins.includes(req.user._id)) {
      return res
        .status(403)
        .json({ message: "Only Group Admins can post notices." });
    }

    // Add to array
    group.notices.push({
      title,
      content,
      postedBy: req.user._id,
      createdAt: new Date(),
    });

    await group.save();
    res.json({ success: true, message: "Notice posted successfully!" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 8. DELETE GROUP ICON (Revert to Default)
// ==========================================
router.delete("/:groupId/icon", verifyToken, async (req, res) => {
  try {
    const group = await Group.findById(req.params.groupId);
    if (!group) return res.status(404).json({ message: "Group not found" });

    // Check Admin Privileges
    if (!group.admins.includes(req.user._id)) {
      return res
        .status(403)
        .json({ message: "Only Admins can remove the icon." });
    }

    group.icon = ""; // Clear the icon string
    await group.save();

    res.json({ success: true, message: "Group icon removed." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 9. DELETE NOTICE
// ==========================================
router.delete("/:groupId/notices/:noticeId", verifyToken, async (req, res) => {
  try {
    const group = await Group.findById(req.params.groupId);
    if (!group) return res.status(404).json({ message: "Group not found" });

    // Find the notice
    const notice = group.notices.id(req.params.noticeId);
    if (!notice) return res.status(404).json({ message: "Notice not found" });

    // Allow Group Admins OR the Original Poster to delete
    const isPoster =
      notice.postedBy && notice.postedBy.toString() === req.user._id;
    const isAdmin = group.admins.includes(req.user._id);

    if (!isPoster && !isAdmin) {
      return res
        .status(403)
        .json({ message: "Unauthorized to delete this notice." });
    }

    // Use pull to remove subdocument
    group.notices.pull(req.params.noticeId);
    await group.save();

    res.json({ success: true, message: "Notice deleted." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
// 10. EDIT NOTICE
// ==========================================
router.put("/:groupId/notices/:noticeId", verifyToken, async (req, res) => {
  try {
    const { title, content } = req.body;
    const group = await Group.findById(req.params.groupId);
    if (!group) return res.status(404).json({ message: "Group not found" });

    const notice = group.notices.id(req.params.noticeId);
    if (!notice) return res.status(404).json({ message: "Notice not found" });

    // Allow Group Admins OR the Original Poster to edit
    const isPoster =
      notice.postedBy && notice.postedBy.toString() === req.user._id;
    const isAdmin = group.admins.includes(req.user._id);

    if (!isPoster && !isAdmin) {
      return res
        .status(403)
        .json({ message: "Unauthorized to edit this notice." });
    }

    if (title) notice.title = title;
    if (content) notice.content = content;

    await group.save();

    res.json({ success: true, message: "Notice updated." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
