const User = require("../models/User");
const asyncHandler = require("../utils/asyncHandler");

// 🧠 AI SMART MATCH
exports.getSmartMatches = asyncHandler(async (req, res) => {
  const currentUser = await User.findById(req.user._id);
  if (!currentUser) return res.status(404).json({ message: "User not found" });

  // 1. Get all other verified users
  const allUsers = await User.find({
    _id: { $ne: currentUser._id },
    isVerified: true,
  }).select(
    "fullName jobTitle organization profilePicture industry skills city state",
  );

  // 2. Calculate Similarity Score
  const matches = allUsers.map((user) => {
    let score = 0;

    // A. Industry Match (High Weight)
    if (
      currentUser.industry &&
      user.industry &&
      currentUser.industry.toLowerCase() === user.industry.toLowerCase()
    ) {
      score += 10;
    }

    // B. Skill Overlap (Medium Weight)
    if (currentUser.skills.length > 0 && user.skills.length > 0) {
      const commonSkills = user.skills.filter((skill) =>
        currentUser.skills.includes(skill),
      );
      score += commonSkills.length * 2;
    }

    // C. Programme Match (Low Weight)
    if (currentUser.programmeTitle === user.programmeTitle) {
      score += 1;
    }

    return { ...user.toObject(), matchScore: score };
  });

  // 3. Sort by Score (Descending) and take top 10
  const topMatches = matches
    .filter((m) => m.matchScore > 0)
    .sort((a, b) => b.matchScore - a.matchScore)
    .slice(0, 10);

  res.json({ success: true, data: topMatches });
});

// 📍 ALUMNI NEAR ME (Travel Mode)
exports.getAlumniNearMe = asyncHandler(async (req, res) => {
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
    city: { $regex: new RegExp(`^${targetCity}$`, "i") }, // Case-insensitive match
  })
    .select(
      "_id fullName profilePicture yearOfAttendance jobTitle organization programmeTitle bio isOnline lastSeen isOpenToMentorship isPhoneVisible phoneNumber email linkedin",
    )
    .limit(10);

  res.json({ success: true, data: nearbyUsers, location: targetCity });
});
