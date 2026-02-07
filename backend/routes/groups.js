const router = require("express").Router();
const Group = require("../models/Group");
const UserProfile = require("../models/UserProfile");
const verifyToken = require("./verifyToken");

// ✅ NEW: Cloudinary & Multer Config for Group Icons
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

      // Check Admin Priveleges
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
// 5. REMOVE MEMBER
// ==========================================
router.put("/:groupId/remove-member", verifyToken, async (req, res) => {
  try {
    const { targetUserId } = req.body;
    const group = await Group.findById(req.params.groupId);

    if (!group) return res.status(404).json({ message: "Group not found" });
    if (!group.admins) group.admins = [];

    if (!group.admins.includes(req.user._id)) {
      return res
        .status(403)
        .json({ message: "Only Group Admins can remove members." });
    }

    group.members = group.members.filter(
      (id) => id.toString() !== targetUserId,
    );
    group.admins = group.admins.filter((id) => id.toString() !== targetUserId);

    await group.save();
    res.json({ success: true, message: "User removed from group." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
