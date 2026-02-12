// backend/services/socketService.js
const { Server } = require("socket.io");
const { createAdapter } = require("@socket.io/redis-adapter");
const { createClient } = require("redis");
const jwt = require("jsonwebtoken");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const Group = require("../models/Group");
const logger = require("../utils/logger");
const { sendPersonalNotification } = require("../utils/notificationHandler");

let io;
const onlineUsers = new Map(); // userId -> Set<socketId>
const disconnectTimers = new Map(); // userId -> TimeoutID

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
  // 1. REDIS ADAPTER SETUP
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
      logger.info("✅ Redis Connected Successfully");
    } catch (err) {
      logger.warn("⚠️ Redis Connection Failed (Using Memory): " + err.message);
    }
  } else {
    logger.info("ℹ️ Running in Memory Mode (Redis disabled).");
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

    // A. JOIN USER ROOM
    socket.join(userId);

    // B. JOIN GROUP ROOMS
    try {
      const userGroups = await Group.find({ members: userId }).select("_id");
      if (userGroups && userGroups.length > 0) {
        userGroups.forEach((group) => {
          socket.join(group._id.toString());
        });
      }
    } catch (err) {
      logger.error(`Error joining group rooms: ${err.message}`);
    }

    socket.on("join_room", (room) => socket.join(room));
    socket.on("leave_room", (room) => socket.leave(room));

    // ==========================================
    // D. WEBRTC SIGNALING (VOICE CALLS)
    // ==========================================

    // 1. Initiate Call (FIXED with Caller Info)
    socket.on("call_user", async (data) => {
      const receiverId = data.userToCall;
      logger.info(`📞 Call initiated by ${socket.userId} to ${receiverId}`);

      try {
        // ✅ FETCH CALLER PROFILE
        const callerProfile = await UserProfile.findOne({
          userId: socket.userId,
        }).select("fullName profilePicture");

        const callerName = callerProfile
          ? callerProfile.fullName
          : "Unknown Caller";
        const callerPic = callerProfile ? callerProfile.profilePicture : null;

        // ✅ EMIT WITH NAME & PIC
        io.to(receiverId).emit("call_made", {
          offer: data.offer,
          socket: socket.id,
          callerId: socket.userId,
          callerName: callerName,
          callerPic: callerPic,
        });

        // Check "official" online status for Notification fallback
        const isReceiverOnline =
          onlineUsers.has(receiverId) && onlineUsers.get(receiverId).size > 0;

        if (!isReceiverOnline) {
          logger.info(
            `📴 User ${receiverId} appears offline. Sending Push Notification.`,
          );
          await sendPersonalNotification(
            receiverId,
            "Incoming Call 📞",
            `${callerName} is calling you...`,
            {
              type: "call_incoming",
              callerId: socket.userId,
              callerName: callerName,
            },
          );
        }
      } catch (err) {
        logger.error(`Call Error: ${err.message}`);
      }
    });

    // 2. Answer Call
    socket.on("make_answer", (data) => {
      logger.info(`📞 Call answered by ${socket.userId}`);
      io.to(data.to).emit("answer_made", {
        socket: socket.id,
        answer: data.answer,
      });
    });

    // 3. ICE Candidates
    socket.on("ice_candidate", (data) => {
      io.to(data.to).emit("ice_candidate_received", {
        candidate: data.candidate,
      });
    });

    handleConnection(socket, userId);
  });

  return io;
};

// ==========================================
// 4. CONNECTION & STATUS LOGIC
// ==========================================
const handleConnection = (socket, userId) => {
  if (disconnectTimers.has(userId)) {
    clearTimeout(disconnectTimers.get(userId));
    disconnectTimers.delete(userId);
  }

  if (!onlineUsers.has(userId)) onlineUsers.set(userId, new Set());
  const previousSocketCount = onlineUsers.get(userId).size;
  onlineUsers.get(userId).add(socket.id);

  if (previousSocketCount === 0) {
    UserAuth.findByIdAndUpdate(userId, { isOnline: true }).catch((e) =>
      logger.error(e),
    );
    io.emit("user_status_update", { userId, isOnline: true });
    logger.info(`🟢 User ${userId} is now Online`);
  }

  socket.on("check_user_status", async ({ userId: targetId }) => {
    if (!targetId) return;
    const isOnline =
      onlineUsers.has(targetId) && onlineUsers.get(targetId).size > 0;
    let lastSeen = null;

    if (!isOnline) {
      try {
        const user = await UserAuth.findById(targetId).select("lastSeen");
        if (user) lastSeen = user.lastSeen;
      } catch (e) {
        logger.error(e.message);
      }
    }
    socket.emit("user_status_result", { userId: targetId, isOnline, lastSeen });
  });

  socket.on("typing", (data) => {
    if (data.groupId) {
      socket.to(data.groupId).emit("typing_start", {
        conversationId: data.conversationId,
        senderId: socket.userId,
        isGroup: true,
      });
    } else if (data.receiverId) {
      io.to(data.receiverId).emit("typing_start", {
        conversationId: data.conversationId,
        senderId: socket.userId,
      });
    }
  });

  socket.on("stop_typing", (data) => {
    if (data.groupId) {
      socket.to(data.groupId).emit("typing_stop", {
        conversationId: data.conversationId,
        senderId: socket.userId,
        isGroup: true,
      });
    } else if (data.receiverId) {
      io.to(data.receiverId).emit("typing_stop", {
        conversationId: data.conversationId,
        senderId: socket.userId,
      });
    }
  });

  socket.on("user_logout", async () => {
    logger.info(`👋 User ${userId} logging out explicitly`);
    cleanupUser(userId);
    try {
      const lastSeen = new Date();
      await UserAuth.findByIdAndUpdate(userId, { isOnline: false, lastSeen });
      io.emit("user_status_update", { userId, isOnline: false, lastSeen });
    } catch (e) {
      logger.error(`Logout Error: ${e.message}`);
    }
  });

  socket.on("disconnect", () => {
    if (!onlineUsers.has(userId)) return;

    const userSockets = onlineUsers.get(userId);
    userSockets.delete(socket.id);

    if (userSockets.size > 0) return;

    const timer = setTimeout(async () => {
      if (!onlineUsers.has(userId) || onlineUsers.get(userId).size === 0) {
        try {
          cleanupUser(userId);
          const lastSeen = new Date();
          await UserAuth.findByIdAndUpdate(userId, {
            isOnline: false,
            lastSeen,
          });
          io.emit("user_status_update", { userId, isOnline: false, lastSeen });
          logger.info(`🔴 User ${userId} went Offline`);
        } catch (e) {
          logger.error(`Socket Error (Disconnect): ${e.message}`);
        }
      }
    }, 5000);

    disconnectTimers.set(userId, timer);
  });
};

const cleanupUser = (userId) => {
  if (disconnectTimers.has(userId)) {
    clearTimeout(disconnectTimers.get(userId));
    disconnectTimers.delete(userId);
  }
  if (onlineUsers.has(userId)) {
    onlineUsers.delete(userId);
  }
};

const getIO = () => {
  if (!io) throw new Error("Socket.io not initialized!");
  return io;
};

module.exports = { initializeSocket, getIO };
