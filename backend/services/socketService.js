// backend/services/socketService.js
const { Server } = require("socket.io");
const { createAdapter } = require("@socket.io/redis-adapter");
const { createClient } = require("redis");
const UserAuth = require("../models/UserAuth");
const Group = require("../models/Group");
const logger = require("../utils/logger");

let io;
const onlineUsers = new Map(); // userId -> Set<socketId>
const disconnectTimers = new Map(); // userId -> TimeoutID (Wait 5s before marking offline)

const initializeSocket = async (server) => {
  const ioConfig = {
    cors: {
      origin: "*", // Allow all origins (Adjust for production if needed)
      methods: ["GET", "POST"],
      credentials: true,
    },
    pingTimeout: 10000,
    pingInterval: 5000,
  };

  io = new Server(server, ioConfig);

  // ==========================================
  // 1. REDIS ADAPTER SETUP (Scalability)
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
      const userId = socket.handshake.query.userId;

      if (!userId || userId === "null" || userId === "undefined") {
        return next(new Error("User ID required in handshake query"));
      }

      socket.userId = userId;
      return next();
    } catch (err) {
      return next(new Error("Internal Server Error during Socket Auth"));
    }
  });

  // ==========================================
  // 3. EVENT HANDLERS
  // ==========================================
  io.on("connection", async (socket) => {
    const userId = socket.userId;
    if (!userId) return;

    logger.info(`🔌 Socket Connected: ${socket.id} (User: ${userId})`);

    // A. JOIN USER ROOM (Immediate Private Messaging)
    socket.join(userId);

    // B. JOIN GROUP ROOMS (Fixes Group Message Delivery)
    try {
      const userGroups = await Group.find({ members: userId }).select("_id");
      if (userGroups && userGroups.length > 0) {
        userGroups.forEach((group) => {
          const groupId = group._id.toString();
          socket.join(groupId);
        });
      }
    } catch (err) {
      logger.error(`Error joining group rooms for ${userId}: ${err.message}`);
    }

    // C. DYNAMIC ROOM MANAGEMENT
    socket.on("join_room", (room) => {
      socket.join(room);
      logger.info(`Socket ${socket.id} joined room ${room}`);
    });

    socket.on("leave_room", (room) => {
      socket.leave(room);
      logger.info(`Socket ${socket.id} left room ${room}`);
    });

    // ==========================================
    // D. WEBRTC SIGNALING (VOICE CALLS)
    // ==========================================

    // 1. Initiate Call
    socket.on("call_user", (data) => {
      logger.info(
        `📞 Call initiated by ${socket.userId} to ${data.userToCall}`,
      );
      io.to(data.userToCall).emit("call_made", {
        offer: data.offer,
        socket: socket.id,
        callerId: socket.userId, // Sent so receiver knows who is calling
      });
    });

    // 2. Answer Call
    socket.on("make_answer", (data) => {
      logger.info(`📞 Call answered by ${socket.userId}`);
      io.to(data.to).emit("answer_made", {
        socket: socket.id,
        answer: data.answer,
      });
    });

    // 3. Exchange ICE Candidates (Connectivity)
    socket.on("ice_candidate", (data) => {
      io.to(data.to).emit("ice_candidate_received", {
        candidate: data.candidate,
      });
    });

    // Handle standard connection logic (Status, Typing, Logout)
    handleConnection(socket, userId);
  });

  return io;
};

// ==========================================
// 4. CONNECTION & STATUS LOGIC
// ==========================================
const handleConnection = (socket, userId) => {
  // --- Online Status Logic ---

  // If user was pending disconnect, cancel it (reconnected quickly)
  if (disconnectTimers.has(userId)) {
    clearTimeout(disconnectTimers.get(userId));
    disconnectTimers.delete(userId);
  }

  // Track socket count for this user
  if (!onlineUsers.has(userId)) onlineUsers.set(userId, new Set());
  const previousSocketCount = onlineUsers.get(userId).size;
  onlineUsers.get(userId).add(socket.id);

  // If this is the first socket, mark user as ONLINE
  if (previousSocketCount === 0) {
    UserAuth.findByIdAndUpdate(userId, { isOnline: true }).catch((e) =>
      logger.error(e),
    );
    io.emit("user_status_update", { userId, isOnline: true });
    logger.info(`🟢 User ${userId} is now Online`);
  }

  // --- Check Status Event ---
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
        logger.error(`Status check error for user ${targetId}: ${e.message}`);
      }
    }
    socket.emit("user_status_result", { userId: targetId, isOnline, lastSeen });
  });

  // --- Typing Events ---
  socket.on("typing", (data) => {
    if (data.groupId) {
      // Broadcast to group room, excluding sender
      socket.to(data.groupId).emit("typing_start", {
        conversationId: data.conversationId,
        senderId: socket.userId,
        isGroup: true,
      });
    } else if (data.receiverId) {
      // Broadcast to user room
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

  // --- Explicit Logout ---
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

  // --- Disconnect ---
  socket.on("disconnect", () => {
    if (!onlineUsers.has(userId)) return;

    const userSockets = onlineUsers.get(userId);
    userSockets.delete(socket.id);

    if (userSockets.size > 0) return;

    // Grace Period (5 seconds) to prevent flickering on page refresh
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
