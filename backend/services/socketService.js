const { Server } = require("socket.io");
const { createAdapter } = require("@socket.io/redis-adapter");
const { createClient } = require("redis");
const jwt = require("jsonwebtoken");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const Group = require("../models/Group");
const Message = require("../models/Message");
const CallLog = require("../models/CallLog"); // ✅ Added Import
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
    // C. MESSAGE STATUS HANDLERS
    // ==========================================

    // 1. Handle "Mark as Read" (When receiver opens the chat)
    socket.on(
      "mark_messages_read",
      async ({ chatId, messageIds, userId: readerId }) => {
        try {
          if (!messageIds || messageIds.length === 0) return;

          // Update in DB
          await Message.updateMany(
            { _id: { $in: messageIds }, conversationId: chatId },
            { $set: { status: "read", isRead: true } },
          );

          // Notify the OTHER participants in the chat (The Senders)
          socket.to(chatId).emit("messages_read_update", {
            chatId,
            messageIds,
            readerId,
          });

          logger.info(
            `✅ Messages marked read in chat: ${chatId} by ${readerId}`,
          );
        } catch (error) {
          logger.error("❌ Error marking messages read:", error);
        }
      },
    );

    // 2. Handle "Delivered" (When app receives message)
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
    // D. WEBRTC SIGNALING & LOGGING
    // ==========================================

    // 1. Initiate Call
    socket.on("call_user", async (data) => {
      const receiverId = data.userToCall;
      logger.info(`📞 Call initiated by ${socket.userId} to ${receiverId}`);

      try {
        const callerProfile = await UserProfile.findOne({
          userId: socket.userId,
        }).select("fullName profilePicture");
        const callerName = callerProfile
          ? callerProfile.fullName
          : "Unknown Caller";
        const callerPic = callerProfile ? callerProfile.profilePicture : null;

        // ✅ Create Call Log in DB
        const newLog = await CallLog.create({
          caller: socket.userId,
          receiver: receiverId,
          status: "ringing",
          callerName: callerName,
          callerPic: callerPic,
        });

        // ✅ Send CallLog ID back to Caller
        socket.emit("call_log_generated", { callLogId: newLog._id });

        const isReceiverOnline =
          onlineUsers.has(receiverId) && onlineUsers.get(receiverId).size > 0;

        // ✅ Send to receiver (even if "offline" logic might trigger, we try emitting)
        // Note: For push notifications, you would trigger FCM here if isReceiverOnline is false
        io.to(receiverId).emit("call_made", {
          offer: data.offer,
          socket: socket.id,
          callerId: socket.userId,
          callerName: callerName,
          callerPic: callerPic,
          callLogId: newLog._id,
        });

        // If strictly offline in socket terms, we can mark as missed,
        // but with Background modes, they might reconnect quickly.
        // We set a short timeout to check if they answered.
        setTimeout(async () => {
          const checkLog = await CallLog.findById(newLog._id);
          if (checkLog && checkLog.status === "ringing") {
            // If still ringing after 30s, mark missed
            await CallLog.findByIdAndUpdate(newLog._id, { status: "missed" });
            io.to(socket.userId).emit("call_failed", { reason: "No answer" });

            // Send Push Notification
            await sendPersonalNotification(
              receiverId,
              "Missed Call 📞",
              `${callerName} tried to call you.`,
              { type: "call_missed", callerId: socket.userId, callerName },
            );
          }
        }, 30000);
      } catch (err) {
        logger.error(`Call Error: ${err.message}`);
      }
    });

    // 2. Answer Call
    socket.on("make_answer", async (data) => {
      logger.info(`📞 Call answered by ${socket.userId}`);

      if (data.callLogId) {
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

          // Notify the other party to close their screen
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

    // 4. ICE Candidates
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

  socket.on("disconnect", async () => {
    // ✅ 1. Remove from active map immediately
    if (onlineUsers.has(userId)) {
      const userSockets = onlineUsers.get(userId);
      userSockets.delete(socket.id);
    }

    // ✅ 2. ACTIVE CALL CLEANUP (The Fix)
    try {
      // Find any call involving this user that is still active
      const activeCall = await CallLog.findOne({
        $or: [{ caller: userId }, { receiver: userId }],
        status: { $in: ["ringing", "ongoing"] },
      });

      if (activeCall) {
        const isCaller = activeCall.caller.toString() === userId;
        const otherParty = isCaller ? activeCall.receiver : activeCall.caller;

        // Mark ended
        await CallLog.findByIdAndUpdate(activeCall._id, {
          status: activeCall.status === "ringing" ? "missed" : "ended",
          endTime: new Date(),
        });

        // Tell the other person
        io.to(otherParty.toString()).emit("call_failed", {
          reason: "User disconnected",
        });
        logger.info(
          `🧹 Auto-cleaned call ${activeCall._id} for disconnected user ${userId}`,
        );
      }
    } catch (err) {
      logger.error(`Call Cleanup Error: ${err.message}`);
    }

    // ✅ 3. Standard Offline Timeout
    if (!onlineUsers.has(userId) || onlineUsers.get(userId).size === 0) {
      const timer = setTimeout(async () => {
        if (!onlineUsers.has(userId) || onlineUsers.get(userId).size === 0) {
          try {
            cleanupUser(userId);
            const lastSeen = new Date();
            await UserAuth.findByIdAndUpdate(userId, {
              isOnline: false,
              lastSeen,
            });
            io.emit("user_status_update", {
              userId,
              isOnline: false,
              lastSeen,
            });
            logger.info(`🔴 User ${userId} went Offline`);
          } catch (e) {
            logger.error(`Socket Error (Disconnect): ${e.message}`);
          }
        }
      }, 5000);
      disconnectTimers.set(userId, timer);
    }
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
