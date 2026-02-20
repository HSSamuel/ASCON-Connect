const { Server } = require("socket.io");
const { createAdapter } = require("@socket.io/redis-adapter");
const { createClient } = require("redis");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const Group = require("../models/Group");
const Message = require("../models/Message");
const logger = require("../utils/logger");

let io;
let redisClient;
const onlineUsersMemory = new Map();
const disconnectTimers = new Map();

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

  io.on("connection", async (socket) => {
    const userId = socket.userId;
    logger.info(`🔌 Socket Connected: ${socket.id} (User: ${userId})`);

    // The user automatically joins a room with their own User ID.
    // This makes it incredibly easy to send targeted events to them!
    socket.join(userId);
    try {
      const userGroups = await Group.find({ members: userId }).select("_id");
      if (userGroups && userGroups.length > 0) {
        userGroups.forEach((group) => socket.join(group._id.toString()));
      }
    } catch (err) {
      logger.error(`Error joining group rooms: ${err.message}`);
    }

    await handleConnection(socket, userId);

    socket.on("join_room", (room) => socket.join(room));
    socket.on("leave_room", (room) => socket.leave(room));

    socket.on("user_connected", async (uid) => {
      if (uid === userId) {
        await handleConnection(socket, userId);
      }
    });

    socket.on("check_user_status", async ({ userId: targetId }) => {
      try {
        const count = await getSocketCount(targetId);
        const isOnline = count > 0;

        let lastSeen = new Date();
        if (!isOnline) {
          const userAuth = await UserAuth.findById(targetId).select("lastSeen");
          if (userAuth) lastSeen = userAuth.lastSeen;
        }

        socket.emit("user_status_update", {
          userId: targetId,
          isOnline: isOnline,
          lastSeen: lastSeen,
        });
      } catch (e) {
        logger.error(`Check Status Error: ${e.message}`);
      }
    });

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

    // --- AGORA CALL SIGNALING ---

    // 1. User A initiates a call to User B
    socket.on("initiate_call", ({ targetUserId, channelName, callerData }) => {
      // Ring User B's phone! (User B is in a room matching their targetUserId)
      socket.to(targetUserId).emit("incoming_call", {
        callerId: userId, // This is the ID of User A (the one making the call)
        channelName,
        callerData,
      });
    });

    // 2. User B clicks the Green "Accept" button
    socket.on("answer_call", ({ targetUserId, channelName }) => {
      // Tell User A to stop ringing and connect the audio
      socket.to(targetUserId).emit("call_answered", { channelName });
    });

    // 3. Someone clicks the Red "Decline/Hang Up" button
    socket.on("end_call", ({ targetUserId, channelName }) => {
      // Tell the other person's phone to close the call screen
      socket.to(targetUserId).emit("call_ended", { channelName });
    });

    socket.on("disconnect", async () => {
      await handleDisconnect(socket, userId);
    });
  });

  return io;
};

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
