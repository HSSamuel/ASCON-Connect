const express = require("express");
const mongoose = require("mongoose");
const dotenv = require("dotenv");
const cors = require("cors");

// 1. Initialize the App
const app = express();
dotenv.config();

// 2. Middlewares
// ✅ FIX 1: CORS MUST be the VERY FIRST middleware
app.use(
  cors({
    origin: "*", // ✅ FIX 2: Allow ALL origins temporarily to fix the "Failed to fetch" error
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "auth-token"],
    credentials: true,
  })
);

// ✅ FIX 3: JSON parsing comes AFTER CORS
app.use(express.json());

// 3. Import Routes
const authRoute = require("./routes/auth");
const directoryRoute = require("./routes/directory");
const adminRoute = require("./routes/admin");
const profileRoute = require("./routes/profile");
const eventsRoute = require("./routes/events");

// 4. Route Middlewares
app.use("/api/auth", authRoute);
app.use("/api/directory", directoryRoute);
app.use("/api/admin", adminRoute);
app.use("/api/profile", profileRoute);
app.use("/api/events", eventsRoute);

// 5. Connect to Database & Start Server
const PORT = process.env.PORT || 5000;

console.log("⏳ Attempting to connect to MongoDB...");

mongoose
  .connect(process.env.DB_CONNECT)
  .then(() => {
    console.log("✅ Connected to MongoDB Successfully!");
    app.listen(PORT, () => {
      console.log(`🚀 Server is running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error("❌ Database Connection Failed:", err);
  });
