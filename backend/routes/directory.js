const router = require("express").Router();
const User = require("../models/User");
const verifyToken = require("./verifyToken"); // ✅ Protected Route

// =========================================================
// 1. DIRECTORY SEARCH (PROTECTED)
// =========================================================
// @route   GET /api/directory
router.get("/", verifyToken, async (req, res) => {
  try {
    const { search, mentorship } = req.query;

    let query = { isVerified: true };

    // 1. Filter by Mentorship Status
    if (mentorship === "true") {
      query.isOpenToMentorship = true;
    }

    // 2. Search Logic
    if (search) {
      const isYear = !isNaN(search);
      if (isYear) {
        query.yearOfAttendance = Number(search);
      } else {
        const sanitizedSearch = search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        query.$text = { $search: sanitizedSearch };
      }
    }

    // ✅ SORTING UPDATE: Show Online & Mentors first
    const alumniList = await User.find(query)
      .sort({ isOnline: -1, isOpenToMentorship: -1, yearOfAttendance: -1 })
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
      isOpenToMentorship: user.isOpenToMentorship,
      // New Fields
      industry: user.industry,
      city: user.city,
    }));

    res.json({ success: true, data: safeList });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 2. SMART CAREER MATCH (AI-LITE)
// =========================================================
// @route   GET /api/directory/smart-matches
router.get("/smart-matches", verifyToken, async (req, res) => {
  try {
    const currentUser = await User.findById(req.user._id);
    if (!currentUser)
      return res.status(404).json({ message: "User not found" });

    // 1. Get all other verified users
    const allUsers = await User.find({
      _id: { $ne: currentUser._id },
      isVerified: true,
    }).select(
      "fullName jobTitle organization profilePicture industry skills city state programmeTitle yearOfAttendance isOpenToMentorship",
    );

    // 2. Calculate Similarity Score
    const matches = allUsers.map((user) => {
      let score = 0;

      // A. Industry Match (High Weight: 10 pts)
      if (
        currentUser.industry &&
        user.industry &&
        currentUser.industry.toLowerCase() === user.industry.toLowerCase()
      ) {
        score += 10;
      }

      // B. Skill Overlap (Medium Weight: 2 pts per skill)
      if (
        currentUser.skills &&
        currentUser.skills.length > 0 &&
        user.skills &&
        user.skills.length > 0
      ) {
        const commonSkills = user.skills.filter((skill) =>
          currentUser.skills.includes(skill),
        );
        score += commonSkills.length * 2;
      }

      // C. Programme/Year Match (Low Weight: 1 pt)
      if (currentUser.programmeTitle === user.programmeTitle) score += 1;
      if (currentUser.yearOfAttendance === user.yearOfAttendance) score += 1;

      return { ...user.toObject(), matchScore: score };
    });

    // 3. Sort by Score (Descending) and take top 15
    const topMatches = matches
      .filter((m) => m.matchScore > 0)
      .sort((a, b) => b.matchScore - a.matchScore)
      .slice(0, 15);

    res.json({ success: true, data: topMatches });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 3. ALUMNI NEAR ME (GEOLOCATION)
// =========================================================
// @route   GET /api/directory/near-me
router.get("/near-me", verifyToken, async (req, res) => {
  try {
    const { city } = req.query; // Allow manual "Travel Mode" override
    const currentUser = await User.findById(req.user._id);

    const targetCity = city || currentUser.city;

    if (!targetCity) {
      return res.json({ success: true, data: [], message: "No location set." });
    }

    // Find users in the same city who have OPTED IN to location sharing
    const nearbyUsers = await User.find({
      _id: { $ne: currentUser._id },
      isVerified: true,
      isLocationVisible: true, // ✅ Privacy Check
      // WITH THIS (Allows "Lagos" to match "Lagos State" or "Ikeja, Lagos"):
      city: { $regex: new RegExp(targetCity, "i") },
    }).select(
      "fullName jobTitle organization profilePicture city state phoneNumber email isOnline",
    );

    res.json({ success: true, data: nearbyUsers, location: targetCity });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 4. OLD RECOMMENDATIONS (Keep for backward compatibility if needed)
// =========================================================
router.get("/recommendations", verifyToken, async (req, res) => {
  try {
    const currentUser = await User.findById(req.user._id);
    const { yearOfAttendance, programmeTitle } = currentUser;

    // Fallback logic
    const matches = await User.find({
      _id: { $ne: currentUser._id },
      isVerified: true,
      $or: [
        { yearOfAttendance: yearOfAttendance },
        { programmeTitle: programmeTitle },
      ],
    })
      .limit(10)
      .select("fullName profilePicture jobTitle organization yearOfAttendance");

    res.json({ success: true, matches });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 5. VERIFICATION ENDPOINT (PUBLIC)
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
