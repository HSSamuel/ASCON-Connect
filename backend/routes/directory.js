const router = require("express").Router();
const User = require("../models/User");

// @route   GET /api/directory
// @desc    Get alumni (Searchable)
router.get("/", async (req, res) => {
  try {
    const { search } = req.query; // Grab '?search=...' from URL

    // 1. Base Query: Always require verified users
    let query = { isVerified: true };

    if (search) {
      const isYear = !isNaN(search);

      if (isYear) {
        query.yearOfAttendance = Number(search);
      } else {
        // ✅ USE TEXT SEARCH (Fast)
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

module.exports = router;
