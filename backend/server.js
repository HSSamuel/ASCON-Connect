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
const http = require("http"); // ✅ NEW: Import HTTP
const { Server } = require("socket.io"); // ✅ NEW: Import Socket.io
const User = require("./models/User"); // ✅ NEW: Import User Model
const validateEnv = require("./utils/validateEnv");
const errorHandler = require("./utils/errorMiddleware");
const logger = require("./utils/logger");

// 1. Initialize the App
const app = express();
const server = http.createServer(app); // ✅ NEW: Wrap Express with HTTP Server

// ✅ FIX: TELL EXPRESS TO TRUST RENDER'S PROXY
app.set("trust proxy", 1);

dotenv.config();
validateEnv();

// ==========================================
// 🛡️ MIDDLEWARE: SECURITY & PERFORMANCE
// ==========================================

// ✅ A. COMPRESSION
app.use(compression());

// ✅ B. HELMET
app.use(helmet());

// ✅ C. MORGAN (Stream logs to Winston)
app.use(
  morgan("combined", {
    stream: { write: (message) => logger.info(message.trim()) },
  }),
);

// ✅ D. RATE LIMITER
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
// 📖 API DOCUMENTATION (SWAGGER)
// ==========================================
const swaggerOptions = {
  swaggerDefinition: {
    openapi: "3.0.0",
    info: {
      title: "ASCON Alumni API",
      version: "1.1.0",
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
// 2. CONFIGURATION (CORS & JSON)
// ==========================================

// ✅ FIX: STRICT ORIGINS FOR PRODUCTION
const allowedOrigins =
  process.env.NODE_ENV === "production"
    ? [
        "https://asconadmin.netlify.app",
        "https://ascon-st50.onrender.com",
        // Add your custom domain here if you have one
      ]
    : ["http://localhost:3000", "http://localhost:5000"];

app.use(
  cors({
    origin: function (origin, callback) {
      // Allow requests with no origin (like mobile apps or curl requests)
      if (!origin) return callback(null, true);
      if (allowedOrigins.indexOf(origin) === -1) {
        const msg =
          "The CORS policy for this site does not allow access from the specified Origin.";
        return callback(new Error(msg), false);
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
// ⚡ SOCKET.IO CONFIGURATION (UPDATED)
// ==========================================
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

app.use((req, res, next) => {
  req.io = io;
  next();
});

io.on("connection", (socket) => {
  // 1. User Joins
  socket.on("user_connected", async (userId) => {
    if (!userId) return;
    socket.userId = userId;
    socket.join(userId); // Join private room

    try {
      await User.findByIdAndUpdate(userId, { isOnline: true });
      io.emit("user_status_update", { userId, isOnline: true });
    } catch (e) {
      logger.error(`Socket Error (Connect): ${e.message}`);
    }
  });

  // ✅ 2. TYPING EVENTS (NEW)
  // Client sends: { receiverId, conversationId }
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

  // 3. User Disconnects
  socket.on("disconnect", async () => {
    if (socket.userId) {
      try {
        await User.findByIdAndUpdate(socket.userId, {
          isOnline: false,
          lastSeen: new Date(),
        });
        io.emit("user_status_update", {
          userId: socket.userId,
          isOnline: false,
          lastSeen: new Date(),
        });
      } catch (e) {
        logger.error(`Socket Error (Disconnect): ${e.message}`);
      }
    }
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
app.use("/api/jobs", require("./routes/jobs"));
app.use("/api/facilities", require("./routes/facilities"));
app.use("/api/chat", chatRoute);
app.use("/api/documents", documentRoute);
app.use("/api/mentorship", mentorshipRoute);

// ✅ CENTRALIZED ERROR HANDLER
app.use(errorHandler);

// ==========================================
// 4. DATABASE & SERVER START
// ==========================================
const PORT = process.env.PORT || 5000;

logger.info("⏳ Attempting to connect to MongoDB...");

mongoose
  .connect(process.env.DB_CONNECT)
  .then(async () => {
    // ✅ Made async to support await inside
    logger.info("✅ Connected to MongoDB Successfully!");

    if (process.env.NODE_ENV === "production") {
      logger.info("🛡️  Production Security Hardening Active");
    }

    // ✅ FIX: RESET ALL USERS TO OFFLINE ON RESTART
    // This prevents "Ghost" online users if the server crashed previously.
    try {
      await User.updateMany({}, { isOnline: false });
      logger.info("🧹 Reset all user statuses to Offline");
    } catch (err) {
      logger.error("⚠️ Failed to reset user statuses:", err);
    }

    // ✅ HEALTH CHECK ROUTE (Keeps the server awake)
    // This defines the homepage route so UptimeRobot has something to ping.
    app.get("/", (req, res) => {
      res.status(200).send("ASCON Server is Awake! 🚀");
    });

    // ✅ UPDATED: Use server.listen instead of app.listen for Socket.io
    server.listen(PORT, () => {
      logger.info(`🚀 Server is running on port ${PORT}`);

      const docsUrl =
        process.env.NODE_ENV === "production"
          ? "https://ascon-st50.onrender.com/api-docs"
          : `http://localhost:${PORT}/api-docs`;

      logger.info(`📖 API Docs available at ${docsUrl}`);
    });
  })
  .catch((err) => {
    logger.error("❌ Database Connection Failed:", err);
  });
