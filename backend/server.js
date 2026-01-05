const express = require("express");
const mongoose = require("mongoose");
const dotenv = require("dotenv");
const cors = require("cors");

// 1. Initialize the App (✅ THIS MUST BE FIRST)
const app = express();
dotenv.config();

// 2. Security Configuration (CORS)
const allowedOrigins = [
  "http://localhost:3000", // Local Admin
  "http://localhost:5000", // Local Server Testing
  "https://asconadmin.netlify.app", // Your Live Admin Panel
  // "https://ascon-alumni-91df2.web.app" // Uncomment if you deploy Flutter Web
];

app.use(
  cors({
    origin: "*", // ⚠️ Allows ANYONE to connect. Use only for testing.
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "auth-token"],
    credentials: true,
  })
);

// 3. Middlewares
app.use(express.json());

// 4. Import Routes
const authRoute = require("./routes/auth");
const directoryRoute = require("./routes/directory");
const adminRoute = require("./routes/admin");
const profileRoute = require("./routes/profile");
const eventsRoute = require("./routes/events");

// 5. Route Middlewares
app.use("/api/auth", authRoute);
app.use("/api/directory", directoryRoute);
app.use("/api/admin", adminRoute);
app.use("/api/profile", profileRoute);
app.use("/api/events", eventsRoute);

// 6. Connect to Database & Start Server
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
