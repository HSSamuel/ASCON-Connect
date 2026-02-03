const router = require("express").Router();
const User = require("../models/User");
const verifyToken = require("./verifyToken"); // ✅ Protected Route

// =========================================================
// 🔒 HELPER: REGEX SANITIZER (PREVENTS ReDoS ATTACKS)
// =========================================================
const escapeRegex = (string) => {
  return string.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
};

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
        const sanitizedSearch = escapeRegex(search); // ✅ Applied security fix here too
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
// ✅ FIX: Moved heavy scoring logic from Node.js RAM to MongoDB Aggregation Pipeline
router.get("/smart-matches", verifyToken, async (req, res) => {
  try {
    const currentUser = await User.findById(req.user._id);
    if (!currentUser)
      return res.status(404).json({ message: "User not found" });

    // Ensure user arrays exist for the aggregation
    const userSkills = currentUser.skills || [];
    const userIndustry = currentUser.industry
      ? currentUser.industry.toLowerCase()
      : "";

    const topMatches = await User.aggregate([
      // 1. Filter out self and unverified users
      { $match: { _id: { $ne: currentUser._id }, isVerified: true } },

      // 2. Calculate match scores for each criteria
      {
        $addFields: {
          industryMatch: {
            $cond: [{ $eq: [{ $toLower: "$industry" }, userIndustry] }, 10, 0],
          },
          programmeMatch: {
            $cond: [
              { $eq: ["$programmeTitle", currentUser.programmeTitle] },
              1,
              0,
            ],
          },
          yearMatch: {
            $cond: [
              { $eq: ["$yearOfAttendance", currentUser.yearOfAttendance] },
              1,
              0,
            ],
          },
          skillMatch: {
            $multiply: [
              {
                $size: {
                  $setIntersection: [{ $ifNull: ["$skills", []] }, userSkills],
                },
              },
              2, // 2 points per matching skill
            ],
          },
        },
      },

      // 3. Sum the total score
      {
        $addFields: {
          matchScore: {
            $add: [
              "$industryMatch",
              "$programmeMatch",
              "$yearMatch",
              "$skillMatch",
            ],
          },
        },
      },

      // 4. Filter only those with at least 1 point, sort, and limit
      { $match: { matchScore: { $gt: 0 } } },
      { $sort: { matchScore: -1 } },
      { $limit: 15 },

      // 5. Project only necessary fields for the frontend
      {
        $project: {
          fullName: 1,
          jobTitle: 1,
          organization: 1,
          profilePicture: 1,
          industry: 1,
          skills: 1,
          city: 1,
          state: 1,
          programmeTitle: 1,
          yearOfAttendance: 1,
          isOpenToMentorship: 1,
          matchScore: 1,
        },
      },
    ]);

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

    // ✅ FIX: Sanitize the city string to prevent Regex DoS attacks
    const safeCity = escapeRegex(targetCity);

    // Find users in the same city who have OPTED IN to location sharing
    const nearbyUsers = await User.find({
      _id: { $ne: currentUser._id },
      isVerified: true,
      isLocationVisible: true, // Privacy Check
      // Matches "Lagos State" or "Ikeja, Lagos" safely
      city: { $regex: new RegExp(safeCity, "i") },
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
