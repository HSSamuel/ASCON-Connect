const admin = require("../config/firebase");
const User = require("../models/User");

/**
 * 📢 SEND BROADCAST (To Everyone)
 * Used for: New Events, New Programmes
 */
const sendBroadcastNotification = async (title, body, data = {}) => {
  try {
    // 1. Find users who have at least one FCM token
    const usersWithTokens = await User.find({
      fcmTokens: { $exists: true, $not: { $size: 0 } },
    });

    if (usersWithTokens.length === 0) {
      console.log("⚠️ No users found with FCM Tokens. Notification skipped.");
      return;
    }

    // 2. Collect all tokens into a single flat array
    const allTokens = usersWithTokens.flatMap((user) => user.fcmTokens);
    console.log(`📣 Sending broadcast to ${allTokens.length} devices...`);

    // 3. Construct Message
    const message = {
      notification: { title, body },
      data: {
        ...data, // e.g., { route: "event_detail", id: "123" }
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      tokens: allTokens,
    };

    // 4. Send Multicast
    const response = await admin.messaging().sendEachForMulticast(message);

    console.log(
      `✅ Broadcast Sent! Success: ${response.successCount}, Fail: ${response.failureCount}`
    );
  } catch (error) {
    console.error("❌ Broadcast Failed:", error);
  }
};

/**
 * 👤 SEND PERSONAL NOTIFICATION (To Specific User)
 * Used for: Account Verification, Profile Updates
 */
const sendPersonalNotification = async (userId, title, body, data = {}) => {
  try {
    const user = await User.findById(userId);
    if (!user || !user.fcmTokens || user.fcmTokens.length === 0) {
      console.log(`⚠️ User ${userId} has no tokens.`);
      return;
    }

    const message = {
      notification: { title, body },
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      tokens: user.fcmTokens, // Send to all user's devices
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(
      `👤 Personal Notification sent to ${user.fullName}: ${response.successCount} success.`
    );
  } catch (error) {
    console.error("❌ Personal Notification Error:", error);
  }
};

module.exports = { sendBroadcastNotification, sendPersonalNotification };
