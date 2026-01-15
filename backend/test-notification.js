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

    // ✅ FIX: Await the connection BEFORE doing anything else
    await mongoose.connect(
      process.env.DB_CONNECT || process.env.DB_CONNECTION,
      {
        useNewUrlParser: true,
        useUnifiedTopology: true,
      }
    );

    console.log("📦 Connected to MongoDB Successfully!");

    // 2. DEFINE TEST USERS
    const testEmails = ["idarajoy199@gmail.com", "smkmayomisamuel@gmail.com"];

    console.log(`🔍 Looking for ${testEmails.length} test users...`);

    for (const email of testEmails) {
      // Now safe to query because we awaited the connection above
      const user = await User.findOne({ email: email });

      if (!user) {
        console.log(`❌ Skipped: Could not find user with email: ${email}`);
        continue;
      }

      // Check for tokens (supports both single 'deviceToken' or array 'fcmTokens')
      const tokens =
        user.fcmTokens || (user.deviceToken ? [user.deviceToken] : []);

      if (!tokens || tokens.length === 0) {
        console.log(`⚠️  User ${user.fullName} found, but has NO FCM TOKENS.`);
        continue;
      }

      console.log(`🚀 Sending personal test to: ${user.fullName}...`);

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

// Run the script
runTest();
