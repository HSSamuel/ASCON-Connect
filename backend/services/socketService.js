const { Server } = require("socket.io");
const { createAdapter } = require("@socket.io/redis-adapter");
const { createClient } = require("redis");
const jwt = require("jsonwebtoken");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const Group = require("../models/Group");
const Message = require("../models/Message");
const CallLog = require("../models/CallLog");
const logger = require("../utils/logger");
const { sendPersonalNotification } = require("../utils/notificationHandler");

let io;
let redisClient; // ✅ Used for Presence (SADD, SREM)
const onlineUsersMemory = new Map(); // Fallback if Redis is disabled
const disconnectTimers = new Map(); // userId -> TimeoutID
const activeCallTimers = new Map(); // callLogId -> TimeoutID

// ==========================================
// 🛠️ PRESENCE HELPERS (Redis vs Memory)
// ==========================================
const addSocketToUser = async (userId, socketId) => {
  if (redisClient && redisClient.isOpen) {
    await redisClient.sAdd(`online_users:${userId}`, socketId);
    await redisClient.expire(`online_users:${userId}`, 86400);
    return await redisClient.sCard(`online_users:${userId}`);
  } else {
    if (!onlineUsersMemory.has(userId))
      onlineUsersMemory.set(userId, new Set());
    onlineUsersMemory.get(userId).add(socketId);
    return onlineUsersMemory.get(userId).size;
  }
};

const removeSocketFromUser = async (userId, socketId) => {
  if (redisClient && redisClient.isOpen) {
    await redisClient.sRem(`online_users:${userId}`, socketId);
    return await redisClient.sCard(`online_users:${userId}`);
  } else {
    if (onlineUsersMemory.has(userId)) {
      onlineUsersMemory.get(userId).delete(socketId);
      return onlineUsersMemory.get(userId).size;
    }
    return 0;
  }
};

const getSocketCount = async (userId) => {
  if (redisClient && redisClient.isOpen) {
    return await redisClient.sCard(`online_users:${userId}`);
  } else {
    return onlineUsersMemory.has(userId)
      ? onlineUsersMemory.get(userId).size
      : 0;
  }
};

const initializeSocket = async (server) => {
  const ioConfig = {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
      credentials: true,
    },
    pingTimeout: 10000,
    pingInterval: 5000,
  };

  io = new Server(server, ioConfig);

  // ==========================================
  // 1. REDIS ADAPTER & CLIENT SETUP
  // ==========================================
  if (process.env.USE_REDIS === "true") {
    logger.info("🔌 Redis Enabled. Attempting to connect...");
    try {
      const pubClient = createClient({
        url: process.env.REDIS_URL || "redis://localhost:6379",
      });
      const subClient = pubClient.duplicate();

      pubClient.on("error", (err) =>
        logger.warn(`Redis Pub Error: ${err.message}`),
      );
      subClient.on("error", (err) =>
        logger.warn(`Redis Sub Error: ${err.message}`),
      );

      await Promise.all([pubClient.connect(), subClient.connect()]);

      io.adapter(createAdapter(pubClient, subClient));
      redisClient = pubClient;

      logger.info("✅ Redis Connected & Adapter Configured");
    } catch (err) {
      logger.warn("⚠️ Redis Connection Failed (Using Memory): " + err.message);
    }
  }

  // ==========================================
  // 2. AUTHENTICATION MIDDLEWARE
  // ==========================================
  io.use(async (socket, next) => {
    try {
      const token =
        socket.handshake.auth?.token ||
        socket.handshake.headers?.["auth-token"] ||
        socket.handshake.headers?.authorization?.split(" ")[1];

      if (!token) {
        return next(new Error("Authentication error: Token required"));
      }

      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = decoded._id;

      return next();
    } catch (err) {
      return next(new Error("Authentication error: Invalid Token"));
    }
  });

  // ==========================================
  // 3. EVENT HANDLERS
  // ==========================================
  io.on("connection", async (socket) => {
    const userId = socket.userId;
    logger.info(`🔌 Socket Connected: ${socket.id} (User: ${userId})`);

    // A. JOIN ROOMS
    socket.join(userId);
    try {
      const userGroups = await Group.find({ members: userId }).select("_id");
      if (userGroups && userGroups.length > 0) {
        userGroups.forEach((group) => socket.join(group._id.toString()));
      }
    } catch (err) {
      logger.error(`Error joining group rooms: ${err.message}`);
    }

    // B. HANDLE CONNECTION (PRESENCE)
    await handleConnection(socket, userId);

    socket.on("join_room", (room) => socket.join(room));
    socket.on("leave_room", (room) => socket.leave(room));

    // ✅ NEW: CHECK USER STATUS ON DEMAND (Fixes Presence Issue)
    socket.on("check_user_status", async ({ userId: targetId }) => {
      try {
        const count = await getSocketCount(targetId);
        const isOnline = count > 0;

        let lastSeen = new Date();
        if (!isOnline) {
          const userAuth = await UserAuth.findById(targetId).select("lastSeen");
          if (userAuth) lastSeen = userAuth.lastSeen;
        }

        // Send result ONLY to the requester
        socket.emit("user_status_update", {
          // Use same event name as broadcast to reuse logic
          userId: targetId,
          isOnline: isOnline,
          lastSeen: lastSeen,
        });
      } catch (e) {
        logger.error(`Check Status Error: ${e.message}`);
      }
    });

    // ==========================================
    // C. MESSAGE STATUS HANDLERS
    // ==========================================
    socket.on(
      "mark_messages_read",
      async ({ chatId, messageIds, userId: readerId }) => {
        try {
          if (!messageIds || messageIds.length === 0) return;
          await Message.updateMany(
            { _id: { $in: messageIds }, conversationId: chatId },
            { $set: { status: "read", isRead: true } },
          );
          socket
            .to(chatId)
            .emit("messages_read_update", { chatId, messageIds, readerId });
        } catch (error) {
          logger.error("❌ Error marking messages read:", error);
        }
      },
    );

    socket.on("message_delivered", async ({ messageId, chatId }) => {
      try {
        const msg = await Message.findByIdAndUpdate(
          messageId,
          { status: "delivered" },
          { new: true },
        );
        if (msg) {
          io.to(chatId).emit("message_status_update", {
            messageId,
            status: "delivered",
            chatId,
          });
        }
      } catch (error) {
        logger.error("Delivered status error:", error);
      }
    });

    // ==========================================
    // D. WEBRTC SIGNALING
    // ==========================================

    // 1. Initiate Call
    socket.on("call_user", async (data) => {
      const receiverId = data.userToCall;
      logger.info(`📞 Call initiated by ${socket.userId} to ${receiverId}`);

      try {
        const busyCheck = await CallLog.findOne({
          $or: [{ caller: receiverId }, { receiver: receiverId }],
          status: { $in: ["ongoing", "ringing"] },
        });

        if (busyCheck) {
          socket.emit("call_failed", { reason: "User is busy" });
          return;
        }

        const callerProfile = await UserProfile.findOne({
          userId: socket.userId,
        }).select("fullName profilePicture");
        const callerName = callerProfile
          ? callerProfile.fullName
          : "Unknown Caller";
        const callerPic = callerProfile ? callerProfile.profilePicture : null;

        const newLog = await CallLog.create({
          caller: socket.userId,
          receiver: receiverId,
          status: "ringing",
          callerName: callerName,
          callerPic: callerPic,
        });

        socket.emit("call_log_generated", { callLogId: newLog._id });

        const payload = {
          offer: data.offer,
          socket: socket.id,
          callerId: socket.userId,
          callerName: callerName,
          callerPic: callerPic,
          callLogId: newLog._id,
        };

        io.to(receiverId).emit("call_made", payload);

        await sendPersonalNotification(
          receiverId,
          "Incoming Call 📞",
          `${callerName} is calling...`,
          {
            type: "call_offer",
            callerId: socket.userId,
            callerName,
            callerPic: callerPic || "",
            callLogId: newLog._id.toString(),
            uuid: newLog._id.toString(),
          },
        );

        const timerId = setTimeout(async () => {
          const checkLog = await CallLog.findById(newLog._id);
          if (checkLog && checkLog.status === "ringing") {
            await CallLog.findByIdAndUpdate(newLog._id, { status: "missed" });
            io.to(socket.userId).emit("call_failed", { reason: "No answer" });
            io.to(receiverId).emit("call_missed", { callLogId: newLog._id });

            await sendPersonalNotification(
              receiverId,
              "Missed Call 📞",
              `${callerName} tried to call you.`,
              { type: "call_missed", callerId: socket.userId, callerName },
            );
          }
          activeCallTimers.delete(newLog._id.toString());
        }, 30000);

        activeCallTimers.set(newLog._id.toString(), timerId);
      } catch (err) {
        logger.error(`Call Error: ${err.message}`);
        socket.emit("call_failed", { reason: "Server Error" });
      }
    });

    // 2. Answer Call
    socket.on("make_answer", async (data) => {
      logger.info(`📞 Call answered by ${socket.userId}`);

      if (data.callLogId) {
        const timerId = activeCallTimers.get(data.callLogId);
        if (timerId) {
          clearTimeout(timerId);
          activeCallTimers.delete(data.callLogId);
        }

        await CallLog.findByIdAndUpdate(data.callLogId, {
          status: "ongoing",
          startTime: new Date(),
        });
      }

      io.to(data.to).emit("answer_made", {
        socket: socket.id,
        answer: data.answer,
      });
    });

    // 3. End Call
    socket.on("end_call", async (data) => {
      if (!data.callLogId) return;

      try {
        const timerId = activeCallTimers.get(data.callLogId);
        if (timerId) {
          clearTimeout(timerId);
          activeCallTimers.delete(data.callLogId);
        }

        const log = await CallLog.findById(data.callLogId);
        if (log && log.status !== "ended" && log.status !== "missed") {
          const endTime = new Date();
          const duration = (endTime - new Date(log.startTime)) / 1000;
          const status = log.status === "ringing" ? "declined" : "ended";

          await CallLog.findByIdAndUpdate(data.callLogId, {
            status: status,
            endTime: endTime,
            duration: status === "ended" ? duration : 0,
          });

          const otherParty =
            log.caller.toString() === socket.userId
              ? log.receiver.toString()
              : log.caller.toString();

          io.to(otherParty).emit("call_ended_remote", {
            callLogId: data.callLogId,
          });
          logger.info(
            `📞 Call ${data.callLogId} ended. Duration: ${duration}s`,
          );
        }
      } catch (e) {
        logger.error(`End Call Error: ${e.message}`);
      }
    });

    socket.on("ice_candidate", (data) => {
      io.to(data.to).emit("ice_candidate_received", {
        candidate: data.candidate,
      });
    });

    // E. DISCONNECT
    socket.on("disconnect", async () => {
      await handleDisconnect(socket, userId);
    });
  });

  return io;
};

// ==========================================
// 4. CONNECTION LOGIC (Redis Adapted)
// ==========================================
const handleConnection = async (socket, userId) => {
  if (disconnectTimers.has(userId)) {
    clearTimeout(disconnectTimers.get(userId));
    disconnectTimers.delete(userId);
  }

  const count = await addSocketToUser(userId, socket.id);

  if (count === 1) {
    await UserAuth.findByIdAndUpdate(userId, { isOnline: true }).catch((e) =>
      logger.error(e),
    );
    io.emit("user_status_update", { userId, isOnline: true });
  }
};

const handleDisconnect = async (socket, userId) => {
  await removeSocketFromUser(userId, socket.id);

  try {
    const activeCall = await CallLog.findOne({
      $or: [{ caller: userId }, { receiver: userId }],
      status: { $in: ["ringing", "ongoing"] },
    });

    if (activeCall) {
      await CallLog.findByIdAndUpdate(activeCall._id, {
        status: activeCall.status === "ringing" ? "missed" : "ended",
        endTime: new Date(),
      });

      const isCaller = activeCall.caller.toString() === userId;
      const otherParty = isCaller ? activeCall.receiver : activeCall.caller;

      io.to(otherParty.toString()).emit("call_failed", {
        reason: "User disconnected",
      });

      if (activeCallTimers.has(activeCall._id.toString())) {
        clearTimeout(activeCallTimers.get(activeCall._id.toString()));
        activeCallTimers.delete(activeCall._id.toString());
      }
    }
  } catch (err) {
    logger.error(`Call Cleanup Error: ${err.message}`);
  }

  const timer = setTimeout(async () => {
    const count = await getSocketCount(userId);

    if (count === 0) {
      const lastSeen = new Date();
      await UserAuth.findByIdAndUpdate(userId, { isOnline: false, lastSeen });
      io.emit("user_status_update", { userId, isOnline: false, lastSeen });
    }
  }, 5000);

  disconnectTimers.set(userId, timer);
};

const getIO = () => {
  if (!io) throw new Error("Socket.io not initialized!");
  return io;
};

module.exports = { initializeSocket, getIO };
