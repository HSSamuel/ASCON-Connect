const router = require("express").Router();
const User = require("../models/User");

// =========================================================
// 1. PUBLIC DIRECTORY SEARCH (With Privacy Shield)
// =========================================================
// @route   GET /api/directory
router.get("/", async (req, res) => {
  try {
    const { search } = req.query;

    let query = { isVerified: true };

    // ✅ Retaining your Search Logic
    if (search) {
      const isYear = !isNaN(search);
      if (isYear) {
        query.yearOfAttendance = Number(search);
      } else {
        query.$text = { $search: search };
      }
    }

    // Fetch users (Sorting & Limit kept same as original)
    const alumniList = await User.find(query)
      .sort({ yearOfAttendance: -1 })
      .limit(50);

    // ✅ PRIVACY SHIELD:
    // Instead of sending the whole user object, we only send these specific fields.
    // This protects emails, phone numbers, and passwords.
    const safeList = alumniList.map((user) => ({
      fullName: user.fullName,
      profilePicture: user.profilePicture,
      programmeTitle: user.programmeTitle,
      yearOfAttendance: user.yearOfAttendance,
      alumniId: user.alumniId,
    }));

    res.json(safeList);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 2. VERIFICATION ENDPOINT (For QR Codes)
// =========================================================
// @route   GET /api/directory/verify/:id
router.get("/verify/:id", async (req, res) => {
  try {
    const { id } = req.params;

    // Convert "ASC-2025-0002" -> "ASC/2025/0002"
    const formattedId = id.replace(/-/g, "/");

    const user = await User.findOne({ alumniId: formattedId });

    if (!user) {
      return res.status(404).json({ message: "ID not found" });
    }

    // ✅ STATUS LOGIC (Dynamic)
    let status = "Active";
    if (!user.isVerified) status = "Pending";
    // if (user.isSuspended) status = "Suspended"; // (Future-proof line)

    // ✅ PRIVACY SHIELD: Explicitly construct public profile
    const publicProfile = {
      fullName: user.fullName,
      profilePicture: user.profilePicture,
      programmeTitle: user.programmeTitle,
      yearOfAttendance: user.yearOfAttendance,
      alumniId: user.alumniId,
      status: status, // Send calculated status (Active/Pending)
    };

    res.json(publicProfile);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server Error" });
  }
});

module.exports = router;
