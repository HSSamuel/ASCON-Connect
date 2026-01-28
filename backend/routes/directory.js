const router = require("express").Router();
const User = require("../models/User");
const verifyToken = require("./verifyToken"); // ✅ Protected Route

// =========================================================
// 1. DIRECTORY SEARCH (PROTECTED)
// =========================================================
// @route   GET /api/directory
// ✅ SECURITY: Added verifyToken. Contact info should not be public.
router.get("/", verifyToken, async (req, res) => {
  try {
    const { search } = req.query;

    let query = { isVerified: true };

    if (search) {
      const isYear = !isNaN(search);
      if (isYear) {
        query.yearOfAttendance = Number(search);
      } else {
        // ✅ Escape special regex chars to prevent crashes
        const sanitizedSearch = search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        query.$text = { $search: sanitizedSearch };
      }
    }

    // Fetch users
    const alumniList = await User.find(query)
      .sort({ yearOfAttendance: -1 })
      .limit(50);

    const safeList = alumniList.map((user) => ({
      _id: user._id,
      fullName: user.fullName,
      profilePicture: user.profilePicture,
      programmeTitle: user.programmeTitle,
      yearOfAttendance: user.yearOfAttendance,
      alumniId: user.alumniId,
      jobTitle: user.jobTitle,
      organization: user.organization,
      bio: user.bio,
      linkedin: user.linkedin,
      phoneNumber: user.phoneNumber,
      email: user.email,
      isOnline: user.isOnline,
      lastSeen: user.lastSeen,
    }));

    res.json(safeList);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 2. VERIFICATION ENDPOINT (PUBLIC)
// =========================================================
// This remains public so Security Guards/HR can scan QR codes
router.get("/verify/:id", async (req, res) => {
  try {
    const { id } = req.params;
    // Handle cases where slashes might be URL-encoded or replaced
    const formattedId = id.replace(/-/g, "/");

    const user = await User.findOne({ alumniId: formattedId });

    if (!user) {
      return res.status(404).json({ message: "ID not found" });
    }

    let status = "Active";
    if (!user.isVerified) status = "Pending";

    // ✅ Minimal Public Profile (No Phone/Email for privacy)
    const publicProfile = {
      fullName: user.fullName,
      profilePicture: user.profilePicture,
      programmeTitle: user.programmeTitle,
      yearOfAttendance: user.yearOfAttendance,
      alumniId: user.alumniId,
      status: status,
      jobTitle: user.jobTitle,
      organization: user.organization,
    };

    res.json(publicProfile);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server Error" });
  }
});

module.exports = router;