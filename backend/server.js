const path = require("path");
const express = require("express");
const mongoose = require("mongoose");
const dotenv = require("dotenv");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const rateLimit = require("express-rate-limit");
const compression = require("compression");
const swaggerJsDoc = require("swagger-jsdoc");
const swaggerUi = require("swagger-ui-express");
const http = require("http");
const { Server } = require("socket.io");
const { createAdapter } = require("@socket.io/redis-adapter");
const { createClient } = require("redis");

// ✅ FIX: Replaced old 'User' model with the new separated models
const UserAuth = require("./models/UserAuth");
const UserProfile = require("./models/UserProfile");

const validateEnv = require("./utils/validateEnv");
const errorHandler = require("./utils/errorMiddleware");
const logger = require("./utils/logger");

// 1. Initialize the App
const app = express();
const server = http.createServer(app);

app.set("trust proxy", 1);
dotenv.config();
validateEnv();

// ==========================================
// 🛡️ MIDDLEWARE
// ==========================================
app.use(compression());
app.use(helmet());
app.use(
  morgan("combined", {
    stream: { write: (message) => logger.info(message.trim()) },
  }),
);

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  validate: { xForwardedForHeader: false },
  message: {
    message:
      "Too many requests from this IP, please try again after 15 minutes.",
  },
});
app.use("/api", limiter);

// ==========================================
// 📖 API DOCUMENTATION
// ==========================================
const swaggerOptions = {
  swaggerDefinition: {
    openapi: "3.0.0",
    info: {
      title: "ASCON Alumni API",
      version: "2.0.0",
      description: "Official API documentation for the ASCON Alumni Platform",
    },
    servers: [
      {
        url:
          process.env.NODE_ENV === "production"
            ? "https://ascon-st50.onrender.com"
            : `http://localhost:${process.env.PORT || 5000}`,
      },
    ],
  },
  apis: [path.join(__dirname, "routes", "*.js")],
};
const swaggerDocs = swaggerJsDoc(swaggerOptions);
app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerDocs));

// ==========================================
// 2. CONFIGURATION
// ==========================================
const allowedOrigins =
  process.env.NODE_ENV === "production"
    ? ["https://asconadmin.netlify.app", "https://ascon-st50.onrender.com"]
    : ["http://localhost:3000", "http://localhost:5000"];

app.use(
  cors({
    origin: function (origin, callback) {
      if (!origin) return callback(null, true);
      if (allowedOrigins.indexOf(origin) === -1) {
        return callback(new Error("CORS policy violation"), false);
      }
      return callback(null, true);
    },
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "auth-token"],
    credentials: true,
  }),
);

app.use(express.json());

// ==========================================
// ⚡ SOCKET.IO SCALABLE PRESENCE SYSTEM
// ==========================================

// ✅ FIX: Define configuration first
const ioConfig = {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
  // ⚡ FASTER HEARTBEAT ⚡
  pingTimeout: 10000, // Detect disconnect in 10 seconds (was 60000)
  pingInterval: 5000, // Send ping every 5 seconds (was 25000)
};

// ✅ FIX: Only initialize Redis if explicitly enabled in .env
if (process.env.USE_REDIS === "true") {
  logger.info("🔌 Redis Enabled. Attempting to connect...");

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

  Promise.all([pubClient.connect(), subClient.connect()])
    .then(() => logger.info("✅ Redis Connected Successfully"))
    .catch((err) =>
      logger.warn("⚠️ Redis Connection Failed (Using Memory): " + err.message),
    );

  ioConfig.adapter = createAdapter(pubClient, subClient);
} else {
  logger.info(
    "ℹ️ Running in Memory Mode (Redis disabled). Set USE_REDIS=true to enable.",
  );
}

// ✅ FIX: Initialize IO once with the correct config
const io = new Server(server, ioConfig);

// 🧠 IN-MEMORY STATE (The "Brain" of the Presence System)
const onlineUsers = new Map(); // Stores userId -> Set<socketId>
const disconnectTimers = new Map(); // Stores userId -> TimeoutID (for debouncing)

app.use((req, res, next) => {
  req.io = io;
  next();
});

io.on("connection", (socket) => {
  // 1. User Connects
  socket.on("user_connected", async (userId) => {
    if (!userId) return;

    socket.userId = userId;
    socket.join(userId);

    // 🛑 STOP the "Offline" Timer if it exists (User reconnected quickly!)
    if (disconnectTimers.has(userId)) {
      clearTimeout(disconnectTimers.get(userId));
      disconnectTimers.delete(userId);
      // No need to emit "Online" because they never officially went offline
      return;
    }

    // Add socket to user's active set
    if (!onlineUsers.has(userId)) {
      onlineUsers.set(userId, new Set());
    }
    const previousSocketCount = onlineUsers.get(userId).size;
    onlineUsers.get(userId).add(socket.id);

    // ✅ ONLY update DB and Emit if this is the FIRST connection
    if (previousSocketCount === 0) {
      try {
        // ✅ FIX: Switched from User to UserAuth
        await UserAuth.findByIdAndUpdate(userId, { isOnline: true });
        io.emit("user_status_update", { userId, isOnline: true });
        logger.info(`🟢 User ${userId} is now Online`);
      } catch (e) {
        logger.error(`Socket Error (Connect): ${e.message}`);
      }
    }
  });

  // ✅ NEW: On-Demand Status Check (Fixes Deep Link Status Issue)
  socket.on("check_user_status", async ({ userId }) => {
    if (!userId) return;

    const isOnline =
      onlineUsers.has(userId) && onlineUsers.get(userId).size > 0;

    let lastSeen = null;
    if (!isOnline) {
      try {
        // ✅ FIX: Switched from User to UserAuth
        const user = await UserAuth.findById(userId).select("lastSeen");
        if (user) lastSeen = user.lastSeen;
      } catch (e) {
        console.error("Status check error", e);
      }
    }

    // Send result back ONLY to the requester
    socket.emit("user_status_result", {
      userId,
      isOnline,
      lastSeen,
    });
  });

  // 2. Typing Events
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

  // ✅ 3. EXPLICIT LOGOUT (Immediate Offline Status)
  // 🔒 SECURE FIX: Do not accept 'userId' from client. Use socket.userId.
  socket.on("user_logout", async () => {
    const userId = socket.userId;
    if (!userId) return;

    logger.info(`👋 User ${userId} logging out explicitly`);

    // Clear all sockets and timers immediately
    if (disconnectTimers.has(userId)) {
      clearTimeout(disconnectTimers.get(userId));
      disconnectTimers.delete(userId);
    }
    if (onlineUsers.has(userId)) {
      onlineUsers.delete(userId);
    }

    try {
      const lastSeen = new Date();
      // ✅ FIX: Switched from User to UserAuth
      await UserAuth.findByIdAndUpdate(userId, {
        isOnline: false,
        lastSeen: lastSeen,
      });

      // Broadcast immediately (No delay)
      io.emit("user_status_update", {
        userId: userId,
        isOnline: false,
        lastSeen: lastSeen,
      });
    } catch (e) {
      logger.error(`Logout Error: ${e.message}`);
    }
  });

  // 4. User Disconnects (With Grace Period for accidental drops)
  socket.on("disconnect", () => {
    const userId = socket.userId;
    if (!userId || !onlineUsers.has(userId)) return;

    const userSockets = onlineUsers.get(userId);
    userSockets.delete(socket.id); // Remove this specific socket

    // If user still has OTHER active sockets (e.g. Web + Mobile), DO NOTHING.
    if (userSockets.size > 0) return;

    // ⏳ If NO sockets left, start the "Grace Period" (5 seconds)
    // This prevents flickering if the user just switched apps or refreshed.
    const timer = setTimeout(async () => {
      // Double check: Are they still gone?
      if (!onlineUsers.has(userId) || onlineUsers.get(userId).size === 0) {
        try {
          onlineUsers.delete(userId); // Cleanup memory
          disconnectTimers.delete(userId);

          const lastSeen = new Date();
          // ✅ FIX: Switched from User to UserAuth
          await UserAuth.findByIdAndUpdate(userId, {
            isOnline: false,
            lastSeen: lastSeen,
          });

          io.emit("user_status_update", {
            userId: userId,
            isOnline: false,
            lastSeen: lastSeen,
          });
          logger.info(`🔴 User ${userId} went Offline`);
        } catch (e) {
          logger.error(`Socket Error (Disconnect): ${e.message}`);
        }
      }
    }, 5000); // 5 Seconds Grace Period

    disconnectTimers.set(userId, timer);
  });
});

// ==========================================
// 3. ROUTES
// ==========================================
const authRoute = require("./routes/auth");
const directoryRoute = require("./routes/directory");
const adminRoutes = require("./routes/admin");
const profileRoute = require("./routes/profile");
const eventsRoute = require("./routes/events");
const programmeInterestRoute = require("./routes/programmeInterest");
const notificationRoutes = require("./routes/notifications");
const eventRegistrationRoute = require("./routes/eventRegistration");
const chatRoute = require("./routes/chat");
const documentRoute = require("./routes/documents");
const mentorshipRoute = require("./routes/mentorship");

app.use("/api/auth", authRoute);
app.use("/api/directory", directoryRoute);
app.use("/api/admin", adminRoutes);
app.use("/api/profile", profileRoute);
app.use("/api/events", eventsRoute);
app.use("/api/programme-interest", programmeInterestRoute);
app.use("/api/notifications", notificationRoutes);
app.use("/api/event-registration", eventRegistrationRoute);
app.use("/api/chat", chatRoute);
app.use("/api/documents", documentRoute);
app.use("/api/mentorship", mentorshipRoute);
app.use("/api/updates", require("./routes/updates"));

app.use(errorHandler);

// ==========================================
// 4. SERVER START
// ==========================================
const PORT = process.env.PORT || 5000;

logger.info("⏳ Attempting to connect to MongoDB...");

mongoose
  .connect(process.env.DB_CONNECT)
  .then(async () => {
    logger.info("✅ Connected to MongoDB Successfully!");

    // ✅ FIX: Switched from User to UserAuth for the server reset query
    try {
      await UserAuth.updateMany({}, { isOnline: false });
      logger.info("🧹 Reset all user statuses to Offline");
    } catch (err) {
      logger.error("⚠️ Failed to reset user statuses:", err);
    }

    app.get("/", (req, res) => {
      res.status(200).send("ASCON Server is Awake! 🚀");
    });

    server.listen(PORT, () => {
      logger.info(`🚀 Server is running on port ${PORT}`);
    });
  })
  .catch((err) => {
    logger.error("❌ Database Connection Failed:", err);
  });
