const admin = require("../config/firebase");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const Notification = require("../models/Notification");
const logger = require("./logger");

const cleanupTokens = async (userId, tokensToRemove) => {
  if (tokensToRemove.length === 0) return;
  try {
    // ✅ FIX: Use UserAuth instead of User
    await UserAuth.findByIdAndUpdate(userId, {
      $pull: { fcmTokens: { $in: tokensToRemove } },
    });
    logger.info(
      `🧹 Cleaned up ${tokensToRemove.length} invalid tokens for user ${userId}`,
    );
  } catch (err) {
    logger.error(`❌ Token Cleanup Error: ${err.message}`);
  }
};

const sendBroadcastNotification = async (title, body, data = {}) => {
  try {
    const newNotification = new Notification({
      title,
      message: body,
      isBroadcast: true,
      data: data,
    });
    await newNotification.save();
    logger.info("💾 Broadcast saved to database.");

    // ✅ FIX: Use UserAuth instead of User
    // Look for BOTH 'fcmTokens' (New) AND 'deviceToken' (Old)
    const usersWithTokens = await UserAuth.find({
      $or: [
        { fcmTokens: { $exists: true, $not: { $size: 0 } } },
        { deviceToken: { $exists: true, $ne: null, $ne: "" } },
      ],
    });

    if (usersWithTokens.length === 0) {
      logger.warn("⚠️ No users found with FCM Tokens. Notification skipped.");
      return;
    }

    logger.info(
      `📣 Preparing broadcast for ${usersWithTokens.length} users...`,
    );

    for (const user of usersWithTokens) {
      // ✅ FIX: Combine New and Old tokens into one unique list
      let allTokens = [];
      if (user.fcmTokens && user.fcmTokens.length > 0) {
        allTokens = [...user.fcmTokens];
      }
      // Add legacy token if it exists and isn't already in the list
      if (user.deviceToken && !allTokens.includes(user.deviceToken)) {
        allTokens.push(user.deviceToken);
      }

      const uniqueTokens = [...new Set(allTokens)];

      if (uniqueTokens.length === 0) continue;

      const message = {
        notification: { title, body },
        // ✅ CRITICAL: Android Channel ID
        android: {
          notification: {
            channelId: "ascon_high_importance",
            priority: "high",
          },
        },
        data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
        tokens: uniqueTokens,
      };

      try {
        const response = await admin.messaging().sendEachForMulticast(message);

        const failedTokens = [];
        response.responses.forEach((res, idx) => {
          if (!res.success) {
            const errorCode = res.error?.code;
            if (
              errorCode === "messaging/registration-token-not-registered" ||
              errorCode === "messaging/invalid-registration-token"
            ) {
              failedTokens.push(uniqueTokens[idx]);
            }
          }
        });

        if (failedTokens.length > 0) {
          await cleanupTokens(user._id, failedTokens);
        }
      } catch (sendError) {
        logger.error(
          `❌ Failed to send to user ${user._id}: ${sendError.message}`,
        );
      }
    }

    logger.info(`✅ Broadcast cycle complete.`);
  } catch (error) {
    logger.error(`❌ Broadcast Failed: ${error.message}`);
  }
};

const sendPersonalNotification = async (userId, title, body, data = {}) => {
  try {
    const newNotification = new Notification({
      recipientId: userId,
      title,
      message: body,
      isBroadcast: false,
      data: data,
    });
    await newNotification.save();

    // ✅ FIX: Use UserAuth instead of User
    const user = await UserAuth.findById(userId);

    // ✅ FIX: Robust Token Check
    let allTokens = [];
    if (user.fcmTokens && user.fcmTokens.length > 0) {
      allTokens = [...user.fcmTokens];
    }
    if (user.deviceToken && !allTokens.includes(user.deviceToken)) {
      allTokens.push(user.deviceToken);
    }

    if (allTokens.length === 0) {
      logger.warn(`⚠️ User ${userId} has no tokens.`);
      return;
    }

    const uniqueTokens = [...new Set(allTokens)];

    const message = {
      notification: { title, body },
      // ✅ CRITICAL: Android Channel ID
      android: {
        notification: {
          channelId: "ascon_high_importance",
          priority: "high",
        },
      },
      data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
      tokens: uniqueTokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    const failedTokens = [];
    response.responses.forEach((res, idx) => {
      if (!res.success) {
        const errorCode = res.error?.code;
        if (
          errorCode === "messaging/registration-token-not-registered" ||
          errorCode === "messaging/invalid-registration-token"
        ) {
          failedTokens.push(uniqueTokens[idx]);
        }
      }
    });

    if (failedTokens.length > 0) {
      await cleanupTokens(user._id, failedTokens);
    }

    logger.info(
      `👤 Personal Notification sent to ${userId}: ${response.successCount} success.`,
    );
  } catch (error) {
    logger.error(`❌ Personal Notification Error: ${error.message}`);
  }
};

module.exports = { sendBroadcastNotification, sendPersonalNotification };
