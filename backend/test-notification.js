require("dotenv").config();
const mongoose = require("mongoose");
const {
  sendPersonalNotification,
  sendBroadcastNotification,
} = require("./utils/notificationHandler");
const User = require("./models/User");

const runTest = async () => {
  try {
    console.log("⏳ Connecting to MongoDB...");

    // ✅ FIX: Removed deprecated options (useNewUrlParser, etc.)
    // Modern Mongoose does not need them and will crash if they are present.
    await mongoose.connect(process.env.DB_CONNECT || process.env.DB_CONNECTION);

    console.log("📦 Connected to MongoDB Successfully!");

    // ============================================================
    // 2. FIND ALL USERS WITH TOKENS (DYNAMIC SCAN)
    // ============================================================
    console.log("🔍 Scanning database for users with active FCM tokens...");

    // Find users who have 'fcmTokens' array with items OR a legacy 'deviceToken'
    const usersWithTokens = await User.find({
      $or: [
        { fcmTokens: { $exists: true, $not: { $size: 0 } } },
        { deviceToken: { $exists: true, $ne: null, $ne: "" } },
      ],
    });

    console.log(`✅ Found ${usersWithTokens.length} users with tokens.`);

    if (usersWithTokens.length === 0) {
      console.log("⚠️  No users found with tokens. Skipping personal tests.");
    }

    for (const user of usersWithTokens) {
      console.log(
        `🚀 Sending personal test to: ${user.fullName} (${user.email})...`
      );

      // 3. TRIGGER PERSONAL NOTIFICATION
      await sendPersonalNotification(
        user._id,
        "Test Internal Alert 🔔",
        `Hello ${user.fullName}, your ASCON Notification is working!`,
        { route: "profile", status: "testing" }
      );
    }

    console.log("\n📢 Sending a Broadcast test to ALL users...");

    // 4. TRIGGER BROADCAST
    await sendBroadcastNotification(
      "Public Announcement 🏛️",
      "This is a broadcast test from the ASCON Backend."
    );

    console.log("\n✅ Test sequence complete. Check your phones!");

    // Close connection cleanly
    await mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error("💥 Test Script Crashed:", error);
    process.exit(1);
  }
};

runTest();
