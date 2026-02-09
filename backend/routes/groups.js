// backend/routes/groups.js
const router = require("express").Router();
const Group = require("../models/Group");
const UserProfile = require("../models/UserProfile");
const Conversation = require("../models/Conversation");
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

// Helper to safely check if a user is an admin
const isUserAdmin = (group, userId) => {
  if (!group || !group.admins) return false;
  return group.admins.some(
    (adminId) => adminId.toString() === userId.toString(),
  );
};

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
      isAdmin: isUserAdmin(group, p.userId),
    }));

    res.json({
      success: true,
      data: {
        ...group,
        members: enrichedMembers,
        admins: group.admins || [],
        isCurrentUserAdmin: isUserAdmin(group, req.user._id),
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

      // ✅ FIX: Safe Admin Check
      if (!isUserAdmin(group, req.user._id)) {
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

    // ✅ FIX: Safe Admin Check
    const amIAdmin = isUserAdmin(group, req.user._id);
    // Allow if I am admin, OR if there are NO admins yet (first setup)
    if (!amIAdmin && group.admins.length > 0) {
      return res
        .status(403)
        .json({ message: "Only Group Admins can do this." });
    }

    // Toggle logic using strings
    const strAdmins = group.admins.map((id) => id.toString());
    const index = strAdmins.indexOf(targetUserId);

    if (index === -1) {
      group.admins.push(targetUserId);
    } else {
      // Find the actual ObjectId index to splice correctly
      const actualIndex = group.admins.findIndex(
        (id) => id.toString() === targetUserId,
      );
      if (actualIndex !== -1) group.admins.splice(actualIndex, 1);
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

    // ✅ FIX: Safe Admin Check
    if (!isUserAdmin(group, req.user._id)) {
      return res
        .status(403)
        .json({ message: "Only Group Admins can remove members." });
    }

    // 1. Remove from Group Model
    group.members = group.members.filter(
      (id) => id.toString() !== targetUserId,
    );
    group.admins = group.admins.filter((id) => id.toString() !== targetUserId);
    await group.save();

    // 2. Remove from Chat Conversation (Database Level)
    await Conversation.updateOne(
      { groupId: req.params.groupId },
      { $pull: { participants: targetUserId } },
    );

    // 3. ✅ REAL-TIME EVICTION: Tell the specific user they are removed
    if (req.io) {
      req.io.to(targetUserId).emit("removed_from_group", {
        groupId: req.params.groupId,
        groupName: group.name,
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
    const group = await Group.findById(req.params.groupId)
      .select("notices")
      .populate("notices.postedBy", "email");

    if (!group) return res.status(404).json({ message: "Group not found" });

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

    // ✅ FIX: Safe Admin Check
    if (!isUserAdmin(group, req.user._id)) {
      return res
        .status(403)
        .json({ message: "Only Group Admins can post notices." });
    }

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

    // ✅ FIX: Safe Admin Check
    if (!isUserAdmin(group, req.user._id)) {
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

    const notice = group.notices.id(req.params.noticeId);
    if (!notice) return res.status(404).json({ message: "Notice not found" });

    const isPoster =
      notice.postedBy && notice.postedBy.toString() === req.user._id;
    // ✅ FIX: Safe Admin Check
    const isAdmin = isUserAdmin(group, req.user._id);

    if (!isPoster && !isAdmin) {
      return res
        .status(403)
        .json({ message: "Unauthorized to delete this notice." });
    }

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

    const isPoster =
      notice.postedBy && notice.postedBy.toString() === req.user._id;
    // ✅ FIX: Safe Admin Check
    const isAdmin = isUserAdmin(group, req.user._id);

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
