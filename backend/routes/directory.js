const router = require("express").Router();
const User = require("../models/User");
const verifyToken = require("./verifyToken"); // ✅ Protected Route

// =========================================================
// 1. DIRECTORY SEARCH (PROTECTED)
// =========================================================
// @route   GET /api/directory
router.get("/", verifyToken, async (req, res) => {
  try {
    const { search, mentorship } = req.query; // ✅ Accept mentorship param

    let query = { isVerified: true };

    // 1. Filter by Mentorship Status
    if (mentorship === 'true') {
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
      isOpenToMentorship: user.isOpenToMentorship, // ✅ Ensure this is sent
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

// =========================================================
// 3. SMART RECOMMENDATIONS (AI-LITE MATCHING)
// =========================================================
// @route   GET /api/directory/recommendations
router.get("/recommendations", verifyToken, async (req, res) => {
  try {
    // 1. Get Current User's Details
    const currentUser = await User.findById(req.user._id);
    if (!currentUser) return res.status(404).json({ message: "User not found" });

    const { yearOfAttendance, programmeTitle, organization, jobTitle } = currentUser;

    // 2. Find Matches
    // Priority 1: Same Year + Same Programme (Classmates)
    // Priority 2: Same Organization (Colleagues)
    const matches = await User.find({
      _id: { $ne: currentUser._id }, // Exclude self
      isVerified: true,
      $or: [
        { 
          yearOfAttendance: yearOfAttendance, 
          programmeTitle: { $regex: new RegExp(`^${programmeTitle}$`, "i") } // Case insensitive
        },
        { 
          organization: { $regex: new RegExp(`^${organization}$`, "i") },
          organization: { $ne: "" } // Ignore empty orgs
        }
      ]
    })
    .select("fullName profilePicture jobTitle organization yearOfAttendance programmeTitle")
    .limit(10); // Limit to top 10 matches

    res.json({
      success: true,
      userYear: yearOfAttendance,
      matches: matches
    });

  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;