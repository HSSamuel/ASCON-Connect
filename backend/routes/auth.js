const router = require("express").Router();
const User = require("../models/User");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const nodemailer = require("nodemailer");
const { OAuth2Client } = require("google-auth-library");

// Initialize Google Client
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// ---------------------------------------------------------
// 1. REGISTER (Standard)
// ---------------------------------------------------------
router.post("/register", async (req, res) => {
  try {
    const { fullName, email, password, yearOfAttendance, certificateNumber } =
      req.body;

    // Check if email exists
    const emailExist = await User.findOne({ email: email });
    if (emailExist) {
      return res.status(400).json({ message: "Email already registered." });
    }

    // Hash Password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Create User
    const newUser = new User({
      fullName,
      email,
      password: hashedPassword,
      yearOfAttendance,
      certificateNumber,
      isVerified: true,
    });

    const savedUser = await newUser.save();

    res.status(201).json({
      message: "Registration successful. Please wait for Admin approval.",
      userId: savedUser._id,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ---------------------------------------------------------
// 2. LOGIN (Standard)
// ---------------------------------------------------------
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    // Check User
    const user = await User.findOne({ email: email });
    if (!user) return res.status(400).json({ message: "Email is not found." });

    // Check Password
    const validPass = await bcrypt.compare(password, user.password);
    if (!validPass)
      return res.status(400).json({ message: "Invalid Password." });

    // Check Verification
    if (user.isVerified === false) {
      return res
        .status(403)
        .json({ message: "Account pending approval. Please contact Admin." });
    }

    // Generate Token (Includes isAdmin flag)
    const token = jwt.sign(
      { _id: user._id, isAdmin: user.isAdmin || false }, // ✅ FIXED: Uses actual DB value
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
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ---------------------------------------------------------
// 3. GOOGLE LOGIN (Hybrid Flow)
// ---------------------------------------------------------
router.post("/google", async (req, res) => {
  try {
    const { token } = req.body;

    // Verify Google Token
    const ticket = await client.verifyIdToken({
      idToken: token,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const { name, email, picture } = ticket.getPayload();

    // Check if user exists
    let user = await User.findOne({ email: email });

    if (user) {
      // --- SCENARIO A: EXISTING USER (LOGIN) ---
      if (!user.isVerified) {
        return res.status(403).json({ message: "Account pending approval." });
      }

      const authToken = jwt.sign(
        { _id: user._id, isAdmin: user.isAdmin || false },
        process.env.JWT_SECRET,
        { expiresIn: "1h" }
      );

      return res.json({
        message: "Login Success",
        token: authToken,
        user: { id: user._id, fullName: user.fullName, email: user.email },
      });
    } else {
      // --- SCENARIO B: NEW USER (PRE-FILL REGISTER) ---
      // We send 404 so the Frontend knows to redirect to Register Screen
      return res.status(404).json({
        message: "User not found",
        googleData: { fullName: name, email: email, photo: picture },
      });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Google Authentication Failed" });
  }
});

// ---------------------------------------------------------
// 4. FORGOT PASSWORD (Real Email)
// ---------------------------------------------------------
router.post("/forgot-password", async (req, res) => {
  try {
    const user = await User.findOne({ email: req.body.email });
    if (!user) return res.status(400).json({ message: "Email not found" });

    // Configure Nodemailer
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS, // App Password
      },
    });

    // Email Content
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: user.email,
      subject: "ASCON Connect - Password Reset",
      text: `Hello ${user.fullName},\n\nYou requested a password reset. \n\nYour User ID for recovery is: ${user._id}\n\n(This ID is handled automatically by the app. Please proceed to set a new password.)`,
    };

    // Send
    await transporter.sendMail(mailOptions);

    res.json({ message: "Reset code sent to your email!", userId: user._id });
  } catch (err) {
    console.error(err);
    res
      .status(500)
      .json({ message: "Email could not be sent. Try again later." });
  }
});

// ---------------------------------------------------------
// 5. RESET PASSWORD
// ---------------------------------------------------------
router.post("/reset-password", async (req, res) => {
  try {
    const { userId, newPassword } = req.body;

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    await User.findByIdAndUpdate(userId, { password: hashedPassword });

    res.json({ message: "Password updated successfully! Please login." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
