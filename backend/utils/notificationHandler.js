const admin = require("../config/firebase");
const User = require("../models/User");

/**
 * 🧹 CLEANUP FUNCTION
 * Removes invalid/expired tokens from a user's database record
 */
const cleanupTokens = async (userId, tokensToRemove) => {
  if (tokensToRemove.length === 0) return;
  try {
    await User.findByIdAndUpdate(userId, {
      $pull: { fcmTokens: { $in: tokensToRemove } },
    });
    console.log(
      `🧹 Cleaned up ${tokensToRemove.length} invalid tokens for user ${userId}`
    );
  } catch (err) {
    console.error("❌ Token Cleanup Error:", err);
  }
};

/**
 * 📢 SEND BROADCAST (To Everyone)
 */
const sendBroadcastNotification = async (title, body, data = {}) => {
  try {
    const usersWithTokens = await User.find({
      fcmTokens: { $exists: true, $not: { $size: 0 } },
    });

    if (usersWithTokens.length === 0) {
      console.log("⚠️ No users found with FCM Tokens. Notification skipped.");
      return;
    }

    console.log(
      `📣 Preparing broadcast for ${usersWithTokens.length} users...`
    );

    // We process users individually or in small batches to handle token cleanup accurately
    for (const user of usersWithTokens) {
      const message = {
        notification: { title, body },
        data: {
          ...data,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        tokens: user.fcmTokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);

      // Check for failed tokens (Unregistered or Invalid)
      const failedTokens = [];
      response.responses.forEach((res, idx) => {
        if (!res.success) {
          const errorCode = res.error?.code;
          if (
            errorCode === "messaging/registration-token-not-registered" ||
            errorCode === "messaging/invalid-registration-token"
          ) {
            failedTokens.push(user.fcmTokens[idx]);
          }
        }
      });

      if (failedTokens.length > 0) {
        await cleanupTokens(user._id, failedTokens);
      }
    }

    console.log(`✅ Broadcast cycle complete.`);
  } catch (error) {
    console.error("❌ Broadcast Failed:", error);
  }
};

/**
 * 👤 SEND PERSONAL NOTIFICATION (To Specific User)
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
      tokens: user.fcmTokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    // Cleanup logic for personal notifications
    const failedTokens = [];
    response.responses.forEach((res, idx) => {
      if (!res.success) {
        const errorCode = res.error?.code;
        if (
          errorCode === "messaging/registration-token-not-registered" ||
          errorCode === "messaging/invalid-registration-token"
        ) {
          failedTokens.push(user.fcmTokens[idx]);
        }
      }
    });

    if (failedTokens.length > 0) {
      await cleanupTokens(user._id, failedTokens);
    }

    console.log(
      `👤 Personal Notification sent to ${user.fullName}: ${response.successCount} success.`
    );
  } catch (error) {
    console.error("❌ Personal Notification Error:", error);
  }
};

module.exports = { sendBroadcastNotification, sendPersonalNotification };
