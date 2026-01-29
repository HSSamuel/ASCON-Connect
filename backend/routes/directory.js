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
    }));

    res.json(safeList);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 2. VERIFICATION ENDPOINT (PUBLIC)
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

// =========================================================
// 3. SMART RECOMMENDATIONS (AI-LITE V2.0)
// =========================================================
// @route   GET /api/directory/recommendations
router.get("/recommendations", verifyToken, async (req, res) => {
  try {
    // 1. Get Current User's Details
    const currentUser = await User.findById(req.user._id);
    if (!currentUser)
      return res.status(404).json({ message: "User not found" });

    const { yearOfAttendance, programmeTitle, organization } = currentUser;

    let matches = [];
    // Keep track of IDs we already found to avoid duplicates
    let excludedIds = [currentUser._id];

    // --- 🕵️ STRATEGY 1: HIGH RELEVANCE (The "Perfect" Matches) ---
    // Finds active colleagues or classmates with "Fuzzy" text matching.
    // e.g. "Chevron" matches "Chevron Nigeria Limited"

    const highQualityMatches = await User.find({
      _id: { $nin: excludedIds },
      isVerified: true,
      $or: [
        // A. Colleagues (Fuzzy Organization Match)
        organization && organization.length > 3
          ? {
              organization: {
                $regex: new RegExp(escapeRegex(organization), "i"),
              },
            }
          : null,

        // B. Classmates (Exact Year + Fuzzy Programme)
        yearOfAttendance && programmeTitle
          ? {
              yearOfAttendance: yearOfAttendance,
              programmeTitle: {
                $regex: new RegExp(escapeRegex(programmeTitle), "i"),
              },
            }
          : null,
      ].filter(Boolean), // Filter out nulls if user profile is incomplete
    })
      .sort({ isOnline: -1, lastSeen: -1 }) // ✅ Prioritize Active Users
      .limit(10)
      .select(
        "fullName profilePicture jobTitle organization yearOfAttendance programmeTitle isOnline",
      );

    matches = [...highQualityMatches];
    matches.forEach((m) => excludedIds.push(m._id));

    // --- 🕵️ STRATEGY 2: FALLBACK (The "Cohort" Matches) ---
    // If Strategy 1 found fewer than 10 people, fill the rest with Classmates (Same Year).
    // This ensures the list is rarely empty.

    if (matches.length < 10 && yearOfAttendance) {
      const limit = 10 - matches.length;

      const cohortMatches = await User.find({
        _id: { $nin: excludedIds },
        isVerified: true,
        yearOfAttendance: yearOfAttendance,
      })
        .sort({ isOnline: -1, lastSeen: -1 }) // Show online classmates first
        .limit(limit)
        .select(
          "fullName profilePicture jobTitle organization yearOfAttendance programmeTitle isOnline",
        );

      matches = [...matches, ...cohortMatches];
      cohortMatches.forEach((m) => excludedIds.push(m._id));
    }

    // --- 🕵️ STRATEGY 3: LAST RESORT (Broad Interest Match) ---
    // If still empty (e.g. user from unique year), find people with same Programme from ANY year.

    if (matches.length < 5 && programmeTitle) {
      const limit = 10 - matches.length;

      const progMatches = await User.find({
        _id: { $nin: excludedIds },
        isVerified: true,
        programmeTitle: {
          $regex: new RegExp(escapeRegex(programmeTitle), "i"),
        },
      })
        .sort({ yearOfAttendance: -1 }) // Recent grads first
        .limit(limit)
        .select(
          "fullName profilePicture jobTitle organization yearOfAttendance programmeTitle isOnline",
        );

      matches = [...matches, ...progMatches];
    }

    res.json({
      success: true,
      userYear: yearOfAttendance,
      matches: matches,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ✅ Helper: Safely escape characters for Regex (prevents crashes with special chars)
function escapeRegex(text) {
  return text.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&");
}

module.exports = router;
