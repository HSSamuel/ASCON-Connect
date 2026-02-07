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

const UserAuth = require("./models/UserAuth");
const validateEnv = require("./utils/validateEnv");
const errorHandler = require("./utils/errorMiddleware");
const logger = require("./utils/logger");

const { initializeSocket } = require("./services/socketService");

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
// 2. CONFIGURATION & ROUTES
// ==========================================

// ✅ IMPROVEMENT: Strict control via ENV
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",")
  : [];

app.use(
  cors({
    origin: function (origin, callback) {
      // Allow requests with no origin (like mobile apps or curl requests)
      if (!origin) return callback(null, true);

      if (allowedOrigins.indexOf(origin) !== -1) {
        return callback(null, true);
      } else {
        // ✅ IMPROVEMENT: Log rejected origin for debugging
        logger.warn(`🚫 Blocked CORS request from: ${origin}`);
        return callback(new Error("Not allowed by CORS"));
      }
    },
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "auth-token"],
    credentials: true,
  }),
);

app.use(express.json());

const ioPromise = initializeSocket(server);

app.use(async (req, res, next) => {
  req.io = await ioPromise;
  next();
});

// ==========================================
// 3. ROUTES
// ==========================================
app.use("/api/auth", require("./routes/auth"));
app.use("/api/directory", require("./routes/directory"));
app.use("/api/admin", require("./routes/admin"));
app.use("/api/profile", require("./routes/profile"));
app.use("/api/events", require("./routes/events"));
app.use("/api/programme-interest", require("./routes/programmeInterest"));
app.use("/api/notifications", require("./routes/notifications"));
app.use("/api/event-registration", require("./routes/eventRegistration"));
app.use("/api/chat", require("./routes/chat"));
app.use("/api/documents", require("./routes/documents"));
app.use("/api/mentorship", require("./routes/mentorship"));
app.use("/api/updates", require("./routes/updates"));
app.use("/api/polls", require("./routes/polls"));
app.use("/api/groups", require("./routes/groups"));

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
