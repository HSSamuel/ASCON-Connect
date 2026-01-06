const express = require("express");
const mongoose = require("mongoose");
const dotenv = require("dotenv");
const cors = require("cors");
const helmet = require("helmet"); // ✅ SECURITY HEADERS
const morgan = require("morgan"); // ✅ LOGGING
const rateLimit = require("express-rate-limit"); // ✅ RATE LIMITING
const compression = require("compression"); // ✅ SPEED OPTIMIZATION

// 1. Initialize the App
const app = express();
dotenv.config();

// ==========================================
// 🛡️ MIDDLEWARE: SECURITY & PERFORMANCE
// ==========================================

// ✅ A. COMPRESSION (Makes responses 70% smaller)
app.use(compression());

// ✅ B. HELMET (Protects HTTP Headers)
app.use(helmet());

// ✅ C. MORGAN (Logs requests to console)
app.use(morgan("common"));

// ✅ D. RATE LIMITER (Prevents Spam/Brute-Force)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per window
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    message:
      "Too many requests from this IP, please try again after 15 minutes.",
  },
});
app.use("/api", limiter); // Apply to all API routes

// ==========================================
// 2. CONFIGURATION (CORS & JSON)
// ==========================================

const allowedOrigins = [
  "http://localhost:3000",
  "http://localhost:5000",
  "https://asconadmin.netlify.app", // Your Admin Panel
];

app.use(
  cors({
    origin: function (origin, callback) {
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
  })
);

app.use(express.json());

// ==========================================
// 3. ROUTES
// ==========================================
const authRoute = require("./routes/auth");
const directoryRoute = require("./routes/directory");
const adminRoute = require("./routes/admin");
const profileRoute = require("./routes/profile");
const eventsRoute = require("./routes/events");
const notificationsRoute = require("./routes/notifications");

app.use("/api/auth", authRoute);
app.use("/api/directory", directoryRoute);
app.use("/api/admin", adminRoute);
app.use("/api/profile", profileRoute);
app.use("/api/events", eventsRoute);
app.use("/api/notifications", notificationsRoute);

// ==========================================
// 4. DATABASE & SERVER START
// ==========================================
const PORT = process.env.PORT || 5000;

console.log("⏳ Attempting to connect to MongoDB...");

mongoose
  .connect(process.env.DB_CONNECT)
  .then(() => {
    console.log("✅ Connected to MongoDB Successfully!");
    app.listen(PORT, () => {
      console.log(`🚀 Server is running on port ${PORT}`);
      console.log(`🛡️  Security & Compression Enabled`);
    });
  })
  .catch((err) => {
    console.error("❌ Database Connection Failed:", err);
  });
