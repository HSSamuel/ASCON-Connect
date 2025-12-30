const express = require("express");
const mongoose = require("mongoose");
const dotenv = require("dotenv");
const cors = require("cors");

// 1. Initialize the App
const app = express();
dotenv.config();

// 2. Middlewares
app.use(express.json());
app.use(cors());

// 3. Import Routes
const authRoute = require("./routes/auth");
const directoryRoute = require("./routes/directory");
const adminRoute = require("./routes/admin");

// 4. Route Middlewares
app.use("/api/auth", authRoute);
app.use("/api/directory", directoryRoute);
app.use("/api/admin", adminRoute);

// 5. Connect to Database FIRST, then Start Server
const PORT = process.env.PORT || 5000;

console.log("⏳ Attempting to connect to MongoDB..."); // Immediate feedback

mongoose
  .connect(process.env.DB_CONNECT)
  .then(() => {
    // Only run this code IF database connects successfully
    console.log("✅ Connected to MongoDB Successfully!");

    app.listen(PORT, () => {
      console.log(`🚀 Server is running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error("❌ Database Connection Failed:", err);
  });
