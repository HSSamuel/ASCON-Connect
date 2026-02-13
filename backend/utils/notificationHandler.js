const admin = require("../config/firebase");
const UserAuth = require("../models/UserAuth");
const Notification = require("../models/Notification");
const logger = require("./logger");

// ✅ Helper: Extract Unique Tokens
const getUniqueTokens = (user) => {
  let allTokens = [];
  if (user.fcmTokens && user.fcmTokens.length > 0) {
    allTokens = [...user.fcmTokens];
  }
  // Legacy support for older schema versions
  if (user.deviceToken && !allTokens.includes(user.deviceToken)) {
    allTokens.push(user.deviceToken);
  }
  return [...new Set(allTokens)];
};

const cleanupTokens = async (userId, tokensToRemove) => {
  if (tokensToRemove.length === 0) return;
  try {
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

    // ✅ Optimize Query: Only fetch needed fields
    const usersWithTokens = await UserAuth.find({
      $or: [
        { fcmTokens: { $exists: true, $not: { $size: 0 } } },
        { deviceToken: { $exists: true, $ne: null, $ne: "" } },
      ],
    }).select("_id fcmTokens deviceToken");

    if (usersWithTokens.length === 0) {
      logger.warn("⚠️ No users found with FCM Tokens. Notification skipped.");
      return;
    }

    logger.info(
      `📣 Preparing broadcast for ${usersWithTokens.length} users...`,
    );

    // ✅ PARALLEL BATCH PROCESSING
    const promises = usersWithTokens.map(async (user) => {
      const uniqueTokens = getUniqueTokens(user);
      if (uniqueTokens.length === 0) return;

      const message = {
        notification: { title, body },
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
        // Log warning but don't stop the broadcast
        logger.warn(`Failed to send to user ${user._id}: ${sendError.message}`);
      }
    });

    await Promise.all(promises);
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

    const user = await UserAuth.findById(userId).select(
      "fcmTokens deviceToken",
    );
    if (!user) return;

    const uniqueTokens = getUniqueTokens(user);
    if (uniqueTokens.length === 0) {
      logger.warn(`⚠️ User ${userId} has no tokens.`);
      return;
    }

    // ✅ DYNAMIC CHANNEL & SOUND LOGIC
    // If it's a call, use the dedicated channel and sound
    const isCall =
      data.type === "call_offer" ||
      data.type === "video_call" ||
      (data.type && data.type.includes("call"));
    const channelId = isCall ? "ascon_call_channel" : "ascon_high_importance";
    const sound = isCall ? "ringtone" : "default";

    const message = {
      notification: { title, body },
      android: {
        notification: {
          channelId: channelId,
          priority: "high",
          sound: sound, // Explicitly request the ringtone file
          visibility: "public",
        },
      },
      // Important: Add channel_id to data so Flutter knows which local channel to fallback to if needed
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        channel_id: channelId,
      },
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
      `👤 Personal Notification sent to ${userId} (Channel: ${channelId}): ${response.successCount} success.`,
    );
  } catch (error) {
    logger.error(`❌ Personal Notification Error: ${error.message}`);
  }
};

module.exports = { sendBroadcastNotification, sendPersonalNotification };
