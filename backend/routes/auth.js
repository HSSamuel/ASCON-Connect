const router = require("express").Router();
const User = require("../models/User");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const { OAuth2Client } = require("google-auth-library");
const Joi = require("joi");
const axios = require("axios");

// Initialize Google Client
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// =========================================================
// 🔧 HELPER FUNCTION: GENERATE AUTHENTIC ALUMNI ID
// =========================================================
// This ensures the ID is unique to the specific Class Year.
// Format: ASC/{YEAR}/{SEQUENCE} (e.g., ASC/2024/0052)
async function generateAlumniId(year) {
  try {
    // 1. Determine the Target Year (Use Input Year or Default to Current)
    const currentYear = new Date().getFullYear().toString();
    const targetYear = year ? year.toString() : currentYear;

    // 2. Search DB for the last ID issued *specifically* for this year
    // Regex matches any string starting with "ASC/2024/"
    const regex = new RegExp(`ASC/${targetYear}/`);

    const lastUser = await User.findOne({ alumniId: { $regex: regex } })
      .sort({ _id: -1 }) // Get the most recently created one
      .limit(1);

    let nextNum = 1;

    if (lastUser && lastUser.alumniId) {
      // Extract the sequence number: "ASC/2024/0042" -> "0042"
      const parts = lastUser.alumniId.split("/");
      const lastNum = parseInt(parts[parts.length - 1]);

      if (!isNaN(lastNum)) {
        nextNum = lastNum + 1; // Increment (42 -> 43)
      }
    }

    // 3. Format with leading zeros (e.g., 5 -> "0005")
    const paddedNum = nextNum.toString().padStart(4, "0");
    return `ASC/${targetYear}/${paddedNum}`;
  } catch (error) {
    console.error("Error generating Alumni ID:", error);
    // Fallback in worst-case scenario to prevent crash
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
  // ✅ FIX: Allow googleToken to prevent "not allowed" errors
  googleToken: Joi.string().optional().allow(null, ""),
});

const loginSchema = Joi.object({
  email: Joi.string().min(6).required().email(),
  password: Joi.string().min(6).required(),
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

    // 4. ✅ GENERATE OFFICIAL ID
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
// 2. LOGIN (With Self-Healing)
// =========================================================
router.post("/login", async (req, res) => {
  const { error } = loginSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const { email, password } = req.body;
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
      user = await user.save();
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
        alumniId: user.alumniId, // ✅ Return the Correct ID
      },
    });
  } catch (err) {
    console.error("Login Error:", err);
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 3. GOOGLE LOGIN (With Self-Healing)
// =========================================================
router.post("/google", async (req, res) => {
  try {
    const { token } = req.body;
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
        user = await user.save();
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
// 4. FORGOT PASSWORD (Using Brevo API)
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
// 5. RESET PASSWORD
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
