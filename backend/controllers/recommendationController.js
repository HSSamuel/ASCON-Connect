const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");
const asyncHandler = require("../utils/asyncHandler");

// =========================================================
// 1. GET SMART RECOMMENDATIONS (Aggregated)
// =========================================================
exports.getRecommendations = asyncHandler(async (req, res) => {
  try {
    const userId = req.user._id;

    // 1. Fetch current user's profile and settings
    const [currentUserProfile, currentUserSettings] = await Promise.all([
      UserProfile.findOne({ userId }),
      UserSettings.findOne({ userId }),
    ]);

    if (!currentUserProfile) {
      return res.status(404).json({ message: "User profile not found." });
    }

    const {
      yearOfAttendance,
      programmeTitle,
      industry,
      skills = [],
    } = currentUserProfile;

    // 2. Determine match criteria based on what the user has filled out
    const matchCriteria = { userId: { $ne: userId } };
    const orConditions = [];

    if (yearOfAttendance) orConditions.push({ yearOfAttendance });
    if (programmeTitle) orConditions.push({ programmeTitle });
    if (industry) orConditions.push({ industry });
    if (skills.length > 0) orConditions.push({ skills: { $in: skills } });

    if (orConditions.length > 0) {
      matchCriteria.$or = orConditions;
    }

    // 3. Aggregate query to fetch matching profiles, auth (for online status), and settings (for mentorship)
    const recommendations = await UserProfile.aggregate([
      { $match: matchCriteria },

      // Join Auth table to check if verified and get online status
      {
        $lookup: {
          from: "userauths",
          localField: "userId",
          foreignField: "_id",
          as: "auth",
        },
      },
      { $unwind: "$auth" },
      { $match: { "auth.isVerified": true } }, // Exclude unverified users

      // Join Settings table to check privacy/mentorship settings
      {
        $lookup: {
          from: "usersettings",
          localField: "userId",
          foreignField: "userId",
          as: "settings",
        },
      },
      { $unwind: "$settings" },

      // Scoring Algorithm
      {
        $addFields: {
          score: {
            $add: [
              { $cond: [{ $eq: ["$programmeTitle", programmeTitle] }, 3, 0] },
              {
                $cond: [{ $eq: ["$yearOfAttendance", yearOfAttendance] }, 2, 0],
              },
              { $cond: [{ $eq: ["$industry", industry] }, 2, 0] },
              {
                $size: {
                  $setIntersection: [{ $ifNull: ["$skills", []] }, skills],
                },
              },
              { $cond: ["$auth.isOnline", 1, 0] }, // Bonus point if online
            ],
          },
        },
      },

      // Sort by best match score
      { $sort: { score: -1, "auth.isOnline": -1 } },
      { $limit: 10 },

      // Project final fields to match Mobile App expectations
      {
        $project: {
          _id: "$userId", // Map userId to _id for mobile compatibility
          fullName: 1,
          jobTitle: 1,
          organization: 1,
          profilePicture: 1,
          bio: 1,
          programmeTitle: 1,
          yearOfAttendance: 1,
          isOnline: "$auth.isOnline",
          lastSeen: "$auth.lastSeen",
          isOpenToMentorship: "$settings.isOpenToMentorship",
          score: 1,
        },
      },
    ]);

    res.status(200).json({ success: true, matches: recommendations });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});
