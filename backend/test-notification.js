require("dotenv").config();
const mongoose = require("mongoose");
const {
  sendPersonalNotification,
  sendBroadcastNotification,
} = require("./utils/notificationHandler");
const User = require("./models/User");

// 1. CONNECT TO MONGODB
mongoose
  .connect(process.env.DB_CONNECT || process.env.DB_CONNECTION)
  .then(() => console.log("📦 Connected to MongoDB for Testing..."))
  .catch((err) => {
    console.error("❌ MongoDB Connection Failed:", err);
    process.exit(1);
  });

const runTest = async () => {
  try {
    // 2. DEFINE TEST USERS
    // ✅ Add as many emails as you want to test here
    const testEmails = [
      "idarajoy199@gmail.com",
      "smkmayomisamuel@gmail.com", // ✅ Added Samuel's email
    ];

    console.log(`🔍 Looking for ${testEmails.length} test users...`);

    for (const email of testEmails) {
      const user = await User.findOne({ email: email });

      if (!user) {
        console.log(`❌ Skipped: Could not find user with email: ${email}`);
        continue;
      }

      if (!user.fcmTokens || user.fcmTokens.length === 0) {
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
    setTimeout(() => process.exit(0), 2000);
  } catch (error) {
    console.error("💥 Test Script Crashed:", error);
    process.exit(1);
  }
};

runTest();
