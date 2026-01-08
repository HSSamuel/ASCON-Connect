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
    // 2. FIND A TEST USER
    // Replace the email with your own account email used in the app
    const testEmail = "idarajoy199@gmail.com";
    const user = await User.findOne({ email: testEmail });

    if (!user) {
      console.log(`❌ Could not find user with email: ${testEmail}`);
      console.log(
        "Tip: Register a user in the app first or change the email in this script."
      );
      process.exit(0);
    }

    if (!user.fcmTokens || user.fcmTokens.length === 0) {
      console.log(`⚠️ User ${user.fullName} found, but has NO FCM TOKENS.`);
      console.log("Tip: Log in to the app on a real device to sync a token.");
      process.exit(0);
    }

    console.log(`🚀 Sending test notification to ${user.fullName}...`);

    // 3. TRIGGER PERSONAL NOTIFICATION
    await sendPersonalNotification(
      user._id,
      "Test Internal Alert 🔔",
      "If you see this, your ASCON Notification System is 100% working!",
      { route: "profile", status: "testing" }
    );

    console.log("\n📢 Sending a Broadcast test to ALL users...");

    // 4. TRIGGER BROADCAST
    await sendBroadcastNotification(
      "Public Announcement 🏛️",
      "This is a broadcast test from the ASCON Backend."
    );

    console.log("\n✅ Test sequence complete. Check your phone!");
    setTimeout(() => process.exit(0), 2000); // Give it time to finish logs
  } catch (error) {
    console.error("💥 Test Script Crashed:", error);
    process.exit(1);
  }
};

runTest();
