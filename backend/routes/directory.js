const router = require("express").Router();
const User = require("../models/User");

// @route   GET /api/directory
// @desc    Get alumni (Searchable)
router.get("/", async (req, res) => {
  try {
    const { search } = req.query; // Grab '?search=...' from URL

    // 1. Base Query: Always require verified users
    let query = { isVerified: true };

    // 2. If user searched for something, add filters
    if (search) {
      const searchRegex = new RegExp(search, "i"); // 'i' = case insensitive

      // Check if the search term looks like a Year (e.g., "2023")
      const isYear = !isNaN(search);

      if (isYear) {
        // Search Name OR Year
        query.$or = [
          { fullName: searchRegex },
          { yearOfAttendance: Number(search) },
        ];
      } else {
        // Search Name OR Job OR Organization
        query.$or = [
          { fullName: searchRegex },
          { jobTitle: searchRegex },
          { organization: searchRegex },
        ];
      }
    }

    // 3. Run Query
    const alumniList = await User.find(query)
      .select("-password") // Hide passwords
      .sort({ yearOfAttendance: -1 }) // Newest graduates first
      .limit(50); // Safety limit: never send more than 50 at once

    res.json(alumniList);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
