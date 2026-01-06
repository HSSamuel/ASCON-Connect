const router = require("express").Router();
const User = require("../models/User");

// =========================================================
// 1. PUBLIC DIRECTORY SEARCH
// =========================================================
// @route   GET /api/directory
router.get("/", async (req, res) => {
  try {
    const { search } = req.query;

    let query = { isVerified: true };

    if (search) {
      const isYear = !isNaN(search);
      if (isYear) {
        query.yearOfAttendance = Number(search);
      } else {
        query.$text = { $search: search };
      }
    }

    // Fetch users
    const alumniList = await User.find(query)
      .sort({ yearOfAttendance: -1 })
      .limit(50);

    // ✅ FIXED PRIVACY SHIELD:
    // We ADD 'bio', 'jobTitle', 'organization', etc. here.
    // If you don't add them, the mobile app receives "undefined".
    const safeList = alumniList.map((user) => ({
      _id: user._id,
      fullName: user.fullName,
      profilePicture: user.profilePicture,
      programmeTitle: user.programmeTitle,
      yearOfAttendance: user.yearOfAttendance,
      alumniId: user.alumniId,

      // 👇 THESE WERE MISSING - ADD THEM NOW 👇
      jobTitle: user.jobTitle,
      organization: user.organization,
      bio: user.bio,
      linkedin: user.linkedin,
      phoneNumber: user.phoneNumber,
      email: user.email,
    }));

    res.json(safeList);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 2. VERIFICATION ENDPOINT
// =========================================================
router.get("/verify/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const formattedId = id.replace(/-/g, "/");
    const user = await User.findOne({ alumniId: formattedId });

    if (!user) {
      return res.status(404).json({ message: "ID not found" });
    }

    let status = "Active";
    if (!user.isVerified) status = "Pending";

    const publicProfile = {
      fullName: user.fullName,
      profilePicture: user.profilePicture,
      programmeTitle: user.programmeTitle,
      yearOfAttendance: user.yearOfAttendance,
      alumniId: user.alumniId,
      status: status,

      // ✅ Add these here too for QR code scanning
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
