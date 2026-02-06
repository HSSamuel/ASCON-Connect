// backend/services/socketService.js
const { Server } = require("socket.io");
const { createAdapter } = require("@socket.io/redis-adapter");
const { createClient } = require("redis");
const UserAuth = require("../models/UserAuth");
const logger = require("../utils/logger");

let io;
const onlineUsers = new Map(); // userId -> Set<socketId>
const disconnectTimers = new Map(); // userId -> TimeoutID

const initializeSocket = async (server) => {
  const ioConfig = {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
    },
    pingTimeout: 10000,
    pingInterval: 5000,
  };

  io = new Server(server, ioConfig);

  // 1. Redis Adapter Setup
  if (process.env.USE_REDIS === "true") {
    logger.info("🔌 Redis Enabled. Attempting to connect...");
    try {
      const pubClient = createClient({ url: process.env.REDIS_URL || "redis://localhost:6379" });
      const subClient = pubClient.duplicate();

      pubClient.on("error", (err) => logger.warn(`Redis Pub Error: ${err.message}`));
      subClient.on("error", (err) => logger.warn(`Redis Sub Error: ${err.message}`));

      await Promise.all([pubClient.connect(), subClient.connect()]);
      io.adapter(createAdapter(pubClient, subClient));
      logger.info("✅ Redis Connected Successfully");
    } catch (err) {
      logger.warn("⚠️ Redis Connection Failed (Using Memory): " + err.message);
    }
  } else {
    logger.info("ℹ️ Running in Memory Mode (Redis disabled).");
  }

  // 2. Event Handlers
  io.on("connection", (socket) => {
    handleConnection(socket);
  });

  return io;
};

const handleConnection = (socket) => {
  // User Connects
  socket.on("user_connected", async (userId) => {
    if (!userId) return;
    socket.userId = userId;
    socket.join(userId);

    // Stop "Offline" Timer if user reconnects quickly
    if (disconnectTimers.has(userId)) {
      clearTimeout(disconnectTimers.get(userId));
      disconnectTimers.delete(userId);
      return;
    }

    if (!onlineUsers.has(userId)) onlineUsers.set(userId, new Set());
    const previousSocketCount = onlineUsers.get(userId).size;
    onlineUsers.get(userId).add(socket.id);

    // Update DB only on first connection
    if (previousSocketCount === 0) {
      try {
        await UserAuth.findByIdAndUpdate(userId, { isOnline: true });
        io.emit("user_status_update", { userId, isOnline: true });
        logger.info(`🟢 User ${userId} is now Online`);
      } catch (e) {
        logger.error(`Socket Error (Connect): ${e.message}`);
      }
    }
  });

  // Check Status
  socket.on("check_user_status", async ({ userId }) => {
    if (!userId) return;
    const isOnline =
      onlineUsers.has(userId) && onlineUsers.get(userId).size > 0;
    let lastSeen = null;

    if (!isOnline) {
      try {
        const user = await UserAuth.findById(userId).select("lastSeen");
        if (user) lastSeen = user.lastSeen;
      } catch (e) {
        // ✅ IMPROVEMENT: Use logger instead of console.error
        logger.error(`Status check error for user ${userId}: ${e.message}`);
      }
    }
    socket.emit("user_status_result", { userId, isOnline, lastSeen });
  });

  // Typing
  socket.on("typing", (data) => {
    if (data.receiverId) {
      io.to(data.receiverId).emit("typing_start", {
        conversationId: data.conversationId,
        senderId: socket.userId,
      });
    }
  });

  socket.on("stop_typing", (data) => {
    if (data.receiverId) {
      io.to(data.receiverId).emit("typing_stop", {
        conversationId: data.conversationId,
        senderId: socket.userId,
      });
    }
  });

  // Explicit Logout
  socket.on("user_logout", async () => {
    const userId = socket.userId;
    if (!userId) return;
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

  // Disconnect
  socket.on("disconnect", () => {
    const userId = socket.userId;
    if (!userId || !onlineUsers.has(userId)) return;

    const userSockets = onlineUsers.get(userId);
    userSockets.delete(socket.id);

    if (userSockets.size > 0) return;

    // Grace Period
    const timer = setTimeout(async () => {
      if (!onlineUsers.has(userId) || onlineUsers.get(userId).size === 0) {
        try {
          cleanupUser(userId);
          const lastSeen = new Date();
          await UserAuth.findByIdAndUpdate(userId, { isOnline: false, lastSeen });
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