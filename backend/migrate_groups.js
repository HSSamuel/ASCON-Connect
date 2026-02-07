const mongoose = require("mongoose");
const dotenv = require("dotenv");
const UserProfile = require("./models/UserProfile");
const Group = require("./models/Group");

// Load Environment Variables
dotenv.config();

const migrateGroups = async () => {
  try {
    console.log("⏳ Connecting to Database...");
    await mongoose.connect(process.env.DB_CONNECT);
    console.log("✅ Database Connected.");

    // 1. Fetch all User Profiles
    const profiles = await UserProfile.find({});
    console.log(`📦 Found ${profiles.length} profiles to process.`);

    let locationCount = 0;
    let classCount = 0;

    for (const profile of profiles) {
      const userId = profile.userId;

      // ---------------------------------------------------------
      // A. Location Chapter (e.g., "Lagos Chapter")
      // ---------------------------------------------------------
      if (profile.city && profile.city.trim().length > 0) {
        const city = profile.city.trim();
        const chapterName = `${city} Chapter`;

        await Group.findOneAndUpdate(
          { name: chapterName, type: "Chapter" },
          {
            $addToSet: { members: userId }, // unique add
            $setOnInsert: {
              description: `Official chapter for alumni in ${city}`,
            },
          },
          { upsert: true, new: true },
        );
        locationCount++;
      }

      // ---------------------------------------------------------
      // B. Class Set Group (e.g., "Class of 2024")
      // ---------------------------------------------------------
      if (profile.yearOfAttendance) {
        const year = profile.yearOfAttendance;
        const className = `Class of ${year}`;

        await Group.findOneAndUpdate(
          { name: className, type: "Class" },
          {
            $addToSet: { members: userId }, // unique add
            $setOnInsert: {
              description: `Official group for the ${className}`,
            },
          },
          { upsert: true, new: true },
        );
        classCount++;
      }

      // Optional: Log progress every 50 users
      if (locationCount % 50 === 0) process.stdout.write(".");
    }

    console.log("\n-----------------------------------");
    console.log("🎉 GROUP MIGRATION COMPLETE!");
    console.log(`📍 Users added to Chapters: ${locationCount}`);
    console.log(`🎓 Users added to Class Sets: ${classCount}`);
    console.log("-----------------------------------");

    process.exit(0);
  } catch (error) {
    console.error("❌ Fatal Error:", error);
    process.exit(1);
  }
};

migrateGroups();
