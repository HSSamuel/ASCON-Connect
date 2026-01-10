const admin = require("../config/firebase");
const User = require("../models/User");
const Notification = require("../models/Notification");
const logger = require("./logger");

const cleanupTokens = async (userId, tokensToRemove) => {
  if (tokensToRemove.length === 0) return;
  try {
    await User.findByIdAndUpdate(userId, {
      $pull: { fcmTokens: { $in: tokensToRemove } },
    });
    logger.info(
      `🧹 Cleaned up ${tokensToRemove.length} invalid tokens for user ${userId}`
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

    const usersWithTokens = await User.find({
      fcmTokens: { $exists: true, $not: { $size: 0 } },
    });

    if (usersWithTokens.length === 0) {
      logger.warn("⚠️ No users found with FCM Tokens. Notification skipped.");
      return;
    }

    logger.info(
      `📣 Preparing broadcast for ${usersWithTokens.length} users...`
    );

    for (const user of usersWithTokens) {
      // ✅ FIX: Remove Duplicate Tokens for this user
      const uniqueTokens = [...new Set(user.fcmTokens)];

      const message = {
        notification: { title, body },
        data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
        tokens: uniqueTokens, // Send to unique list
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
          `❌ Failed to send to user ${user._id}: ${sendError.message}`
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

    const user = await User.findById(userId);
    if (!user || !user.fcmTokens || user.fcmTokens.length === 0) {
      logger.warn(`⚠️ User ${userId} has no tokens.`);
      return;
    }

    // ✅ FIX: Remove Duplicate Tokens
    const uniqueTokens = [...new Set(user.fcmTokens)];

    const message = {
      notification: { title, body },
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
      `👤 Personal Notification sent to ${user.fullName}: ${response.successCount} success.`
    );
  } catch (error) {
    logger.error(`❌ Personal Notification Error: ${error.message}`);
  }
};

module.exports = { sendBroadcastNotification, sendPersonalNotification };
