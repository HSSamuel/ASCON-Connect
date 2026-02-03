const router = require("express").Router();
// ✅ NEW: Import the 3 separated models
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");

const verifyToken = require("./verifyToken");

// =========================================================
// 🔒 HELPER: REGEX SANITIZER (PREVENTS ReDoS ATTACKS)
// =========================================================
const escapeRegex = (string) => {
  return string.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
};

// =========================================================
// 1. DIRECTORY SEARCH (PROTECTED)
// =========================================================
router.get("/", verifyToken, async (req, res) => {
  try {
    const { search, mentorship } = req.query;

    let profileMatch = {};
    let settingsMatch = {};

    // Filter by Mentorship Status
    if (mentorship === "true") {
      settingsMatch["settings.isOpenToMentorship"] = true;
    }

    // Search Logic (Profile Text Search)
    if (search) {
      const isYear = !isNaN(search);
      if (isYear) {
        profileMatch.yearOfAttendance = Number(search);
      } else {
        const sanitizedSearch = escapeRegex(search);
        profileMatch.$text = { $search: sanitizedSearch };
      }
    }

    // ✅ NEW: MongoDB Aggregation Pipeline to join the 3 tables
    const alumniList = await UserProfile.aggregate([
      { $match: profileMatch },
      // Join with Auth table to check if verified and get online status
      {
        $lookup: {
          from: "userauths",
          localField: "userId",
          foreignField: "_id",
          as: "auth",
        },
      },
      { $unwind: "$auth" },
      { $match: { "auth.isVerified": true } }, // Only show verified users
      // Join with Settings table
      {
        $lookup: {
          from: "usersettings",
          localField: "userId",
          foreignField: "userId",
          as: "settings",
        },
      },
      { $unwind: "$settings" },
      { $match: settingsMatch }, // Apply settings filters (e.g., mentorship)
      {
        $sort: {
          "auth.isOnline": -1,
          "settings.isOpenToMentorship": -1,
          yearOfAttendance: -1,
        },
      },
      { $limit: 50 },
      // Project final fields to match mobile app expectations
      {
        $project: {
          _id: "$userId", // ✅ Crucial: Send Auth ID as the main _id
          fullName: 1,
          profilePicture: 1,
          programmeTitle: 1,
          yearOfAttendance: 1,
          alumniId: 1,
          jobTitle: 1,
          organization: 1,
          bio: 1,
          linkedin: 1,
          phoneNumber: 1,
          industry: 1,
          city: 1,
          email: "$auth.email",
          isOnline: "$auth.isOnline",
          lastSeen: "$auth.lastSeen",
          isOpenToMentorship: "$settings.isOpenToMentorship",
        },
      },
    ]);

    res.json({ success: true, data: alumniList });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 2. SMART CAREER MATCH (AI-LITE)
// =========================================================
router.get("/smart-matches", verifyToken, async (req, res) => {
  try {
    const currentProfile = await UserProfile.findOne({ userId: req.user._id });
    if (!currentProfile)
      return res.status(404).json({ message: "User not found" });

    const userSkills = currentProfile.skills || [];
    const userIndustry = currentProfile.industry
      ? currentProfile.industry.toLowerCase()
      : "";

    const topMatches = await UserProfile.aggregate([
      { $match: { userId: { $ne: req.user._id } } }, // Exclude self
      // Join Auth to ensure verified
      {
        $lookup: {
          from: "userauths",
          localField: "userId",
          foreignField: "_id",
          as: "auth",
        },
      },
      { $unwind: "$auth" },
      { $match: { "auth.isVerified": true } },
      // Join Settings for mentorship flag
      {
        $lookup: {
          from: "usersettings",
          localField: "userId",
          foreignField: "userId",
          as: "settings",
        },
      },
      { $unwind: "$settings" },

      // Calculate scores
      {
        $addFields: {
          industryMatch: {
            $cond: [{ $eq: [{ $toLower: "$industry" }, userIndustry] }, 10, 0],
          },
          programmeMatch: {
            $cond: [
              { $eq: ["$programmeTitle", currentProfile.programmeTitle] },
              1,
              0,
            ],
          },
          yearMatch: {
            $cond: [
              { $eq: ["$yearOfAttendance", currentProfile.yearOfAttendance] },
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
              2,
            ],
          },
        },
      },
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
      { $match: { matchScore: { $gt: 0 } } },
      { $sort: { matchScore: -1 } },
      { $limit: 15 },
      {
        $project: {
          _id: "$userId", // Map userId to _id
          fullName: 1,
          jobTitle: 1,
          organization: 1,
          profilePicture: 1,
          industry: 1,
          skills: 1,
          city: 1,
          programmeTitle: 1,
          yearOfAttendance: 1,
          isOnline: "$auth.isOnline",
          lastSeen: "$auth.lastSeen",
          isOpenToMentorship: "$settings.isOpenToMentorship",
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
router.get("/near-me", verifyToken, async (req, res) => {
  try {
    const { city } = req.query;
    const currentProfile = await UserProfile.findOne({ userId: req.user._id });

    const targetCity = city || currentProfile.city;

    if (!targetCity) {
      return res.json({ success: true, data: [], message: "No location set." });
    }

    const safeCity = escapeRegex(targetCity);

    const nearbyUsers = await UserProfile.aggregate([
      {
        $match: {
          userId: { $ne: req.user._id },
          city: { $regex: new RegExp(safeCity, "i") },
        },
      },
      {
        $lookup: {
          from: "userauths",
          localField: "userId",
          foreignField: "_id",
          as: "auth",
        },
      },
      { $unwind: "$auth" },
      { $match: { "auth.isVerified": true } },
      {
        $lookup: {
          from: "usersettings",
          localField: "userId",
          foreignField: "userId",
          as: "settings",
        },
      },
      { $unwind: "$settings" },
      { $match: { "settings.isLocationVisible": true } }, // Privacy Check
      {
        $project: {
          _id: "$userId",
          fullName: 1,
          jobTitle: 1,
          organization: 1,
          profilePicture: 1,
          city: 1,
          phoneNumber: 1,
          email: "$auth.email",
          isOnline: "$auth.isOnline",
          lastSeen: "$auth.lastSeen",
          isOpenToMentorship: "$settings.isOpenToMentorship",
        },
      },
    ]);

    res.json({ success: true, data: nearbyUsers, location: targetCity });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 4. RECOMMENDATIONS (FOR CAROUSEL)
// =========================================================
router.get("/recommendations", verifyToken, async (req, res) => {
  try {
    const currentProfile = await UserProfile.findOne({ userId: req.user._id });
    if (!currentProfile)
      return res.status(404).json({ message: "Profile not found" });

    const { yearOfAttendance, programmeTitle } = currentProfile;

    const matches = await UserProfile.aggregate([
      {
        $match: {
          userId: { $ne: req.user._id },
          $or: [{ yearOfAttendance }, { programmeTitle }],
        },
      },
      {
        $lookup: {
          from: "userauths",
          localField: "userId",
          foreignField: "_id",
          as: "auth",
        },
      },
      { $unwind: "$auth" },
      { $match: { "auth.isVerified": true } },
      {
        $lookup: {
          from: "usersettings",
          localField: "userId",
          foreignField: "userId",
          as: "settings",
        },
      },
      { $unwind: "$settings" },
      { $limit: 10 },
      {
        $project: {
          _id: "$userId",
          fullName: 1,
          profilePicture: 1,
          jobTitle: 1,
          organization: 1,
          yearOfAttendance: 1,
          bio: 1,
          programmeTitle: 1,
          phoneNumber: 1,
          linkedin: 1,
          email: "$auth.email",
          isOnline: "$auth.isOnline",
          lastSeen: "$auth.lastSeen",
          isOpenToMentorship: "$settings.isOpenToMentorship",
          isPhoneVisible: "$settings.isPhoneVisible",
        },
      },
    ]);

    res.json({ success: true, matches });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 5. SINGLE ALUMNI DETAILS (NEW FIX)
// =========================================================
router.get("/:userId", verifyToken, async (req, res) => {
  try {
    // Parallel Fetching for instant response
    const [auth, profile, settings] = await Promise.all([
      UserAuth.findById(req.params.userId).select(
        "email isOnline lastSeen isVerified",
      ),
      UserProfile.findOne({ userId: req.params.userId }),
      UserSettings.findOne({ userId: req.params.userId }),
    ]);

    if (!profile || !auth)
      return res.status(404).json({ message: "User not found" });

    const fullDetails = {
      _id: auth._id,
      email: auth.email,
      isOnline: auth.isOnline,
      lastSeen: auth.lastSeen,
      isVerified: auth.isVerified,
      ...profile.toObject(),
      ...settings.toObject(),
    };

    res.json({ success: true, data: fullDetails });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 6. VERIFICATION ENDPOINT (PUBLIC)
// =========================================================
router.get("/verify/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const formattedId = id.replace(/-/g, "/");

    const profile = await UserProfile.findOne({ alumniId: formattedId });
    if (!profile) return res.status(404).json({ message: "ID not found" });

    const auth = await UserAuth.findById(profile.userId);

    const publicProfile = {
      fullName: profile.fullName,
      profilePicture: profile.profilePicture,
      programmeTitle: profile.programmeTitle,
      yearOfAttendance: profile.yearOfAttendance,
      alumniId: profile.alumniId,
      status: auth?.isVerified ? "Active" : "Pending",
      jobTitle: profile.jobTitle,
      organization: profile.organization,
    };

    res.json(publicProfile);
  } catch (err) {
    res.status(500).json({ message: "Server Error" });
  }
});

module.exports = router;
