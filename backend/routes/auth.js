const router = require("express").Router();
const User = require("../models/User");
const Counter = require("../models/Counter"); // ✅ IMPORT COUNTER MODEL
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const { OAuth2Client } = require("google-auth-library");
const Joi = require("joi");
const axios = require("axios");

// Initialize Google Client
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// =========================================================
// 🔧 HELPER FUNCTION: GENERATE AUTHENTIC ALUMNI ID (ATOMIC)
// =========================================================
// This ensures the ID is unique even if users register simultaneously.
// Format: ASC/{YEAR}/{SEQUENCE} (e.g., ASC/2024/0052)
async function generateAlumniId(year) {
  try {
    const currentYear = new Date().getFullYear().toString();
    const targetYear = year ? year.toString() : currentYear;
    const counterId = `alumni_id_${targetYear}`;

    // ✅ ATOMIC UPDATE: Find the counter and increment it safely
    const counter = await Counter.findByIdAndUpdate(
      counterId,
      { $inc: { seq: 1 } },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    );

    // Format with leading zeros (e.g., 5 -> "0005")
    const paddedNum = counter.seq.toString().padStart(4, "0");
    return `ASC/${targetYear}/${paddedNum}`;
  } catch (error) {
    console.error("Error generating Alumni ID:", error);
    // Fallback only if database fails completely
    return `ASC/${new Date().getFullYear()}/ERR-${Date.now()
      .toString()
      .slice(-4)}`;
  }
}

// =========================================================
// 📝 VALIDATION SCHEMAS
// =========================================================
const registerSchema = Joi.object({
  fullName: Joi.string().min(6).required(),
  email: Joi.string().min(6).required().email(),
  password: Joi.string().min(6).required(),
  phoneNumber: Joi.string().required(),
  programmeTitle: Joi.string().optional().allow(""),
  yearOfAttendance: Joi.alternatives()
    .try(Joi.string(), Joi.number())
    .optional()
    .allow(null, ""),
  customProgramme: Joi.string().optional().allow(""),
  googleToken: Joi.string().optional().allow(null, ""),
});

const loginSchema = Joi.object({
  email: Joi.string().min(6).required().email(),
  password: Joi.string().min(6).required(),
  fcmToken: Joi.string().optional().allow(""), // ✅ Allow FCM Token in Login
});

// =========================================================
// 1. REGISTER (With Auto-ID)
// =========================================================
router.post("/register", async (req, res) => {
  // 1. Validate Input
  const { error } = registerSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const {
      fullName,
      email,
      password,
      phoneNumber,
      yearOfAttendance,
      programmeTitle,
      customProgramme,
    } = req.body;

    // 2. Check for Duplicate Email
    const emailExist = await User.findOne({ email });
    if (emailExist)
      return res.status(400).json({ message: "Email already registered." });

    // 3. Hash Password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // 4. ✅ GENERATE OFFICIAL ID (ATOMIC)
    const newAlumniId = await generateAlumniId(yearOfAttendance);

    // 5. Create User
    const newUser = new User({
      fullName,
      email,
      password: hashedPassword,
      phoneNumber,
      yearOfAttendance,
      programmeTitle,
      customProgramme: customProgramme || "",
      isVerified: true, // Auto-Approve for MVP
      alumniId: newAlumniId, // ✅ Save Authentic ID
      hasSeenWelcome: false,
    });

    const savedUser = await newUser.save();

    // 6. Create Session Token
    const token = jwt.sign(
      { _id: savedUser._id, isAdmin: false, canEdit: false },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );

    res.status(201).json({
      message: "Registration successful!",
      token: token,
      user: {
        id: savedUser._id,
        fullName: savedUser.fullName,
        email: savedUser.email,
        alumniId: savedUser.alumniId,
        hasSeenWelcome: false,
      },
    });
  } catch (err) {
    console.error("Register Error:", err);
    res.status(500).json({ message: "Server Error during Registration" });
  }
});

// =========================================================
// 2. LOGIN (With Self-Healing & Multi-Device Notifications)
// =========================================================
router.post("/login", async (req, res) => {
  const { error } = loginSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const { email, password, fcmToken } = req.body;
    let user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "Email is not found." });

    const validPass = await bcrypt.compare(password, user.password);
    if (!validPass)
      return res.status(400).json({ message: "Invalid Password." });

    if (user.isVerified === false)
      return res.status(403).json({ message: "Account pending approval." });

    // ✅ SELF-HEALING: If ID is missing/broken, Fix it now!
    if (!user.alumniId || user.alumniId === "PENDING" || user.alumniId === "") {
      console.log(`🔧 Auto-Fixing ID for user: ${user.fullName}`);
      user.alumniId = await generateAlumniId(user.yearOfAttendance);
      await user.save();
    }

    // ✅ NOTIFICATION: Add Device Token
    if (fcmToken) {
      await User.updateOne(
        { _id: user._id },
        { $addToSet: { fcmTokens: fcmToken } } // Adds only if unique
      );
    }

    const token = jwt.sign(
      {
        _id: user._id,
        isAdmin: user.isAdmin || false,
        canEdit: user.canEdit || false,
      },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );

    res.header("auth-token", token).json({
      token: token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        isAdmin: user.isAdmin,
        canEdit: user.canEdit,
        profilePicture: user.profilePicture,
        hasSeenWelcome: user.hasSeenWelcome || false,
        alumniId: user.alumniId,
      },
    });
  } catch (err) {
    console.error("Login Error:", err);
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 3. LOGOUT (Remove Device Token)
// =========================================================
router.post("/logout", async (req, res) => {
  try {
    const { userId, fcmToken } = req.body;
    if (userId && fcmToken) {
      await User.updateOne(
        { _id: userId },
        { $pull: { fcmTokens: fcmToken } } // Remove this specific device
      );
    }
    res.status(200).json({ message: "Logged out successfully" });
  } catch (err) {
    console.error("Logout Error:", err);
    res.status(500).json({ message: "Logout failed" });
  }
});

// =========================================================
// 4. GOOGLE LOGIN (With Self-Healing)
// =========================================================
router.post("/google", async (req, res) => {
  try {
    const { token, fcmToken } = req.body; // Accept fcmToken here too
    const ticket = await client.verifyIdToken({
      idToken: token,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const { name, email, picture } = ticket.getPayload();

    let user = await User.findOne({ email });

    if (user) {
      if (!user.isVerified)
        return res.status(403).json({ message: "Account pending approval." });

      // ✅ SELF-HEALING: Fix ID if missing
      if (!user.alumniId || user.alumniId === "PENDING") {
        user.alumniId = await generateAlumniId(user.yearOfAttendance);
        await user.save();
      }

      // ✅ NOTIFICATION: Add Device Token
      if (fcmToken) {
        await User.updateOne(
          { _id: user._id },
          { $addToSet: { fcmTokens: fcmToken } }
        );
      }

      const authToken = jwt.sign(
        {
          _id: user._id,
          isAdmin: user.isAdmin || false,
          canEdit: user.canEdit || false,
        },
        process.env.JWT_SECRET,
        { expiresIn: "1h" }
      );

      return res.json({
        message: "Login Success",
        token: authToken,
        user: {
          id: user._id,
          fullName: user.fullName,
          email: user.email,
          isAdmin: user.isAdmin,
          canEdit: user.canEdit,
          profilePicture: user.profilePicture,
          hasSeenWelcome: user.hasSeenWelcome || false,
          alumniId: user.alumniId,
        },
      });
    } else {
      // User must register first
      return res.status(404).json({
        message: "User not found",
        googleData: { fullName: name, email: email, photo: picture },
      });
    }
  } catch (err) {
    console.error("Google Auth Error:", err);
    res.status(500).json({ message: "Google Authentication Failed" });
  }
});

// =========================================================
// 5. FORGOT PASSWORD (Using Brevo API)
// =========================================================
router.post("/forgot-password", async (req, res) => {
  try {
    if (!req.body.email)
      return res.status(400).json({ message: "Email is required" });

    const user = await User.findOne({ email: req.body.email });
    if (!user) return res.status(400).json({ message: "Email not found" });

    // Generate Reset Token
    const token = crypto.randomBytes(20).toString("hex");
    user.resetPasswordToken = token;
    user.resetPasswordExpires = Date.now() + 3600000; // 1 hour
    await user.save();

    const resetUrl = `https://asconadmin.netlify.app/reset-password?token=${token}`;

    // Send Email via Brevo
    await axios.post(
      "https://api.brevo.com/v3/smtp/email",
      {
        sender: { name: "ASCON Alumni", email: process.env.EMAIL_USER },
        to: [{ email: user.email, name: user.fullName }],
        subject: "ASCON Alumni - Password Reset",
        htmlContent: `
          <h3>Password Reset Request</h3>
          <p>Hello ${user.fullName},</p>
          <p>You requested a password reset. Click the link below:</p>
          <p><a href="${resetUrl}" style="background-color: #1B5E3A; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Reset Password</a></p>
          <p>Or copy this link: ${resetUrl}</p>
          <p>If you did not request this, please ignore this email.</p>
        `,
      },
      {
        headers: {
          "api-key": process.env.EMAIL_PASS,
          "Content-Type": "application/json",
        },
      }
    );

    res.json({ message: "Reset link sent to your email!" });
  } catch (err) {
    console.error(
      "Brevo API Error:",
      err.response ? err.response.data : err.message
    );
    res.status(500).json({ message: "Could not send email. Try again later." });
  }
});

// =========================================================
// 6. RESET PASSWORD
// =========================================================
router.post("/reset-password", async (req, res) => {
  try {
    const { token, newPassword } = req.body;
    if (!newPassword || newPassword.length < 6)
      return res.status(400).json({ message: "Password too short." });

    const user = await User.findOne({
      resetPasswordToken: token,
      resetPasswordExpires: { $gt: Date.now() },
    });
    if (!user)
      return res.status(400).json({ message: "Invalid or expired token." });

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    user.password = hashedPassword;
    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;

    await user.save();
    res.json({ message: "Password updated successfully! Please login." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
