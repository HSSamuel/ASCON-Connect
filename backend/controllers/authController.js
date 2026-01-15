const User = require("../models/User");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const { OAuth2Client } = require("google-auth-library");
const Joi = require("joi");
const axios = require("axios");
const { generateAlumniId } = require("../utils/idGenerator");

const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// --------------------------------------------------------------------------
// VALIDATION SCHEMAS
// --------------------------------------------------------------------------
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
  fcmToken: Joi.string().optional().allow(""),
});

// --------------------------------------------------------------------------
// 1. REGISTER (Manual Creation)
// --------------------------------------------------------------------------
exports.register = async (req, res) => {
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

    // Check if user exists (Google or Local)
    const emailExist = await User.findOne({ email });
    if (emailExist)
      return res
        .status(400)
        .json({ message: "Email already registered. Please Login." });

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const newAlumniId = await generateAlumniId(yearOfAttendance);

    const newUser = new User({
      fullName,
      email,
      password: hashedPassword,
      phoneNumber,
      yearOfAttendance,
      programmeTitle,
      customProgramme: customProgramme || "",
      isVerified: true,
      alumniId: newAlumniId,
      hasSeenWelcome: false,
      provider: "local", // ✅ Mark as Local
    });

    const savedUser = await newUser.save();

    const token = jwt.sign(
      { _id: savedUser._id, isAdmin: false, canEdit: false },
      process.env.JWT_SECRET,
      { expiresIn: "2h" }
    );

    const refreshToken = jwt.sign(
      { _id: savedUser._id },
      process.env.REFRESH_SECRET,
      { expiresIn: "30d" }
    );

    res.status(201).json({
      message: "Registration successful!",
      token: token,
      refreshToken: refreshToken,
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
};

// --------------------------------------------------------------------------
// 2. LOGIN (Manual Credentials)
// --------------------------------------------------------------------------
exports.login = async (req, res) => {
  const { error } = loginSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const { email, password, fcmToken } = req.body;
    let user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "Email is not found." });

    // ✅ HYBRID CHECK: We allow login even if they are a Google user,
    // as long as they have a valid password.

    const validPass = await bcrypt.compare(password, user.password);
    if (!validPass)
      return res.status(400).json({ message: "Invalid Password." });

    if (user.isVerified === false)
      return res.status(403).json({ message: "Account pending approval." });

    // Auto-Repair Alumni ID
    if (!user.alumniId || user.alumniId === "PENDING" || user.alumniId === "") {
      const yearToUse = user.yearOfAttendance || new Date().getFullYear();
      user.alumniId = await generateAlumniId(yearToUse);
      await user.save();
    }

    if (fcmToken) {
      await User.updateOne(
        { _id: user._id },
        { $addToSet: { fcmTokens: fcmToken } }
      );
    }

    const token = jwt.sign(
      { _id: user._id, isAdmin: user.isAdmin, canEdit: user.canEdit },
      process.env.JWT_SECRET,
      { expiresIn: "2h" }
    );

    const refreshToken = jwt.sign(
      { _id: user._id },
      process.env.REFRESH_SECRET,
      { expiresIn: "30d" }
    );

    res.json({
      token,
      refreshToken,
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
};

// --------------------------------------------------------------------------
// 3. GOOGLE LOGIN (Universal Support)
// --------------------------------------------------------------------------
exports.googleLogin = async (req, res) => {
  try {
    const { token, fcmToken } = req.body;
    let name, email, picture;

    // Detect Token Type (ID Token vs Access Token)
    const isIdToken = token.split(".").length === 3;
    if (isIdToken) {
      const ticket = await client.verifyIdToken({
        idToken: token,
        audience: process.env.GOOGLE_CLIENT_ID,
      });
      const payload = ticket.getPayload();
      name = payload.name;
      email = payload.email;
      picture = payload.picture;
    } else {
      const response = await axios.get(
        "https://www.googleapis.com/oauth2/v3/userinfo",
        { headers: { Authorization: `Bearer ${token}` } }
      );
      name = response.data.name;
      email = response.data.email;
      picture = response.data.picture;
    }

    // ✅ FIND USER
    let user = await User.findOne({ email });

    // ✅ SCENARIO A: User does NOT exist -> Create new Google Account
    if (!user) {
      const currentYear = new Date().getFullYear();
      const randomPassword = crypto.randomBytes(16).toString("hex");
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(randomPassword, salt);
      const newAlumniId = await generateAlumniId(currentYear);

      user = new User({
        fullName: name,
        email: email,
        password: hashedPassword,
        phoneNumber: "",
        yearOfAttendance: currentYear,
        profilePicture: picture,
        isVerified: true,
        alumniId: newAlumniId,
        hasSeenWelcome: false,
        provider: "google",
      });

      await user.save();
    }
    // ✅ SCENARIO B: User DOES exist (Manual or Google) -> Log them in!
    // We do NOT block them if they registered manually. We just grant access.

    if (!user.isVerified)
      return res.status(403).json({ message: "Account pending approval." });

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
      { expiresIn: "2h" }
    );

    const refreshToken = jwt.sign(
      { _id: user._id },
      process.env.REFRESH_SECRET,
      { expiresIn: "30d" }
    );

    return res.json({
      token: authToken,
      refreshToken: refreshToken,
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
    console.error("Google Auth Error:", err);
    res.status(500).json({ message: "Google Authentication Failed" });
  }
};

// --------------------------------------------------------------------------
// 4. REFRESH TOKEN
// --------------------------------------------------------------------------
exports.refreshToken = async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken)
    return res.status(401).json({ message: "Refresh Token Required" });

  try {
    const verified = jwt.verify(refreshToken, process.env.REFRESH_SECRET);
    const user = await User.findById(verified._id);

    const newAccessToken = jwt.sign(
      { _id: user._id, isAdmin: user.isAdmin, canEdit: user.canEdit },
      process.env.JWT_SECRET,
      { expiresIn: "2h" }
    );

    res.json({ token: newAccessToken });
  } catch (err) {
    res.status(403).json({ message: "Invalid Refresh Token" });
  }
};

// --------------------------------------------------------------------------
// 5. FORGOT PASSWORD (Universal)
// --------------------------------------------------------------------------
exports.forgotPassword = async (req, res) => {
  try {
    if (!req.body.email)
      return res.status(400).json({ message: "Email is required" });

    const user = await User.findOne({ email: req.body.email });
    if (!user) return res.status(400).json({ message: "Email not found" });

    const token = crypto.randomBytes(20).toString("hex");
    user.resetPasswordToken = token;
    user.resetPasswordExpires = Date.now() + 3600000;
    await user.save();

    const resetUrl = `https://asconadmin.netlify.app/reset-password?token=${token}`;

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
          <p><a href="${resetUrl}">Reset Password</a></p>
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
    res.status(500).json({ message: "Could not send email. Try again later." });
  }
};

// --------------------------------------------------------------------------
// 6. RESET PASSWORD EXECUTE
// --------------------------------------------------------------------------
exports.resetPassword = async (req, res) => {
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
};

// --------------------------------------------------------------------------
// 7. LOGOUT
// --------------------------------------------------------------------------
exports.logout = async (req, res) => {
  try {
    const { userId, fcmToken } = req.body;
    if (userId && fcmToken) {
      await User.updateOne({ _id: userId }, { $pull: { fcmTokens: fcmToken } });
    }
    res.status(200).json({ message: "Logged out successfully" });
  } catch (err) {
    res.status(500).json({ message: "Logout failed" });
  }
};
