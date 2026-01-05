const router = require("express").Router();
const User = require("../models/User");

// @route   GET /api/directory
// @desc    Get alumni (Searchable)
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

    const alumniList = await User.find(query)
      .select("-password")
      .sort({ yearOfAttendance: -1 })
      .limit(50);

    res.json(alumniList);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ✅ ADD THIS: Verification Route
// @route   GET /api/directory/verify/:id
// @desc    Public endpoint to verify a user by Alumni ID
router.get("/verify/:id", async (req, res) => {
  try {
    const { id } = req.params;

    // The ID comes in as "ASC-2026-0052" (dashes)
    // We convert it to "ASC/2026/0052" (slashes) to match the DB
    const formattedId = id.replace(/-/g, "/");

    const user = await User.findOne({ alumniId: formattedId }).select(
      "fullName programmeTitle yearOfAttendance profilePicture alumniId isVerified"
    );

    if (!user) {
      return res.status(404).json({ message: "ID not found" });
    }

    res.json(user);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server Error" });
  }
});

module.exports = router;
