const router = require("express").Router();
const User = require("../models/User");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const { OAuth2Client } = require("google-auth-library");
const Joi = require("joi");
const axios = require("axios"); // ✅ Using Axios for API calls

// Initialize Google Client
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// ---------------------------------------------------------
// VALIDATION SCHEMAS
// ---------------------------------------------------------
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
});

const loginSchema = Joi.object({
  email: Joi.string().min(6).required().email(),
  password: Joi.string().min(6).required(),
});

// ---------------------------------------------------------
// 1. REGISTER
// ---------------------------------------------------------
router.post("/register", async (req, res) => {
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

    const emailExist = await User.findOne({ email });
    if (emailExist)
      return res.status(400).json({ message: "Email already registered." });

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const newUser = new User({
      fullName,
      email,
      password: hashedPassword,
      phoneNumber,
      yearOfAttendance,
      programmeTitle,
      customProgramme: customProgramme || "",
      isVerified: true,
      hasSeenWelcome: false,
    });

    const savedUser = await newUser.save();
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
        hasSeenWelcome: false,
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ---------------------------------------------------------
// 2. LOGIN
// ---------------------------------------------------------
router.post("/login", async (req, res) => {
  const { error } = loginSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "Email is not found." });

    const validPass = await bcrypt.compare(password, user.password);
    if (!validPass)
      return res.status(400).json({ message: "Invalid Password." });

    if (user.isVerified === false)
      return res.status(403).json({ message: "Account pending approval." });

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
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ---------------------------------------------------------
// 3. GOOGLE LOGIN
// ---------------------------------------------------------
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
        },
      });
    } else {
      return res
        .status(404)
        .json({
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
// 4. FORGOT PASSWORD (✅ NUCLEAR OPTION: HTTP API)
// ---------------------------------------------------------
router.post("/forgot-password", async (req, res) => {
  try {
    if (!req.body.email)
      return res.status(400).json({ message: "Email is required" });

    const user = await User.findOne({ email: req.body.email });
    if (!user) return res.status(400).json({ message: "Email not found" });

    // 1. Generate Token
    const token = crypto.randomBytes(20).toString("hex");
    user.resetPasswordToken = token;
    user.resetPasswordExpires = Date.now() + 3600000; // 1 hour
    await user.save();

    // 2. Create Link
    const resetUrl = `https://asconadmin.netlify.app/reset-password?token=${token}`;

    // 3. Send via Brevo API (No SMTP, No Ports, No Blockers)
    await axios.post(
      "https://api.brevo.com/v3/smtp/email",
      {
        sender: { name: "ASCON Alumni", email: process.env.EMAIL_USER },
        to: [{ email: user.email, name: user.fullName }],
        subject: "ASCON Alumni - Password Reset",
        htmlContent: `
          <h3>Password Reset Request</h3>
          <p>Hello ${user.fullName},</p>
          <p>Please click the link below to reset your password:</p>
          <p><a href="${resetUrl}" style="background-color: #1B5E3A; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Reset Password</a></p>
          <p>Or copy this link: ${resetUrl}</p>
        `,
      },
      {
        headers: {
          "api-key": process.env.EMAIL_PASS, // Uses the 'xkeysib-' key from Env Vars
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

// ---------------------------------------------------------
// 5. RESET PASSWORD
// ---------------------------------------------------------
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
