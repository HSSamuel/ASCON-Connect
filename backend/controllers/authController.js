const mongoose = require("mongoose");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");
const Group = require("../models/Group");

const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const { OAuth2Client } = require("google-auth-library");
const Joi = require("joi");
const axios = require("axios");
const { generateAlumniId } = require("../utils/idGenerator");
const asyncHandler = require("../utils/asyncHandler");
const { sendPersonalNotification } = require("../utils/notificationHandler");

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
  city: Joi.string().optional().allow(""),
  googleToken: Joi.string().optional().allow(null, ""),
  fcmToken: Joi.string().optional().allow(null, ""),
});

const loginSchema = Joi.object({
  email: Joi.string().min(6).required().email(),
  password: Joi.string().min(6).required(),
  fcmToken: Joi.string().optional().allow("", null),
});

// ✅ HELPER: Manage Tokens in the Auth Schema (Cap at 5)
const manageFcmToken = async (userId, token) => {
  if (!token) return;
  await UserAuth.findByIdAndUpdate(userId, {
    $pull: { fcmTokens: token },
  });
  await UserAuth.findByIdAndUpdate(userId, {
    $push: {
      fcmTokens: {
        $each: [token],
        $position: 0,
        $slice: 5,
      },
    },
  });
};

// --------------------------------------------------------------------------
// 1. REGISTER (Atomic Transaction Implemented)
// --------------------------------------------------------------------------
exports.register = asyncHandler(async (req, res) => {
  const { error } = registerSchema.validate(req.body);
  if (error) {
    res.status(400);
    throw new Error(error.details[0].message);
  }

  const {
    fullName,
    email,
    password,
    phoneNumber,
    yearOfAttendance,
    programmeTitle,
    customProgramme,
    city,
    fcmToken,
  } = req.body;

  // 1. Check if Auth exists (Read-only, no transaction needed yet)
  const emailExist = await UserAuth.findOne({ email });
  if (emailExist) {
    res.status(400);
    throw new Error("Email already registered. Please Login.");
  }

  // ✅ START TRANSACTION
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);
    const newAlumniId = await generateAlumniId(yearOfAttendance);

    // STEP 1: Create Auth
    const newUserAuth = new UserAuth({
      email,
      password: hashedPassword,
      isVerified: true,
      provider: "local",
      fcmTokens: fcmToken ? [fcmToken] : [],
      isOnline: true,
    });
    const savedAuth = await newUserAuth.save({ session });

    // STEP 2: Create Profile
    const newUserProfile = new UserProfile({
      userId: savedAuth._id,
      fullName,
      phoneNumber,
      yearOfAttendance,
      programmeTitle,
      customProgramme: customProgramme || "",
      city: city || "",
      alumniId: newAlumniId,
    });
    await newUserProfile.save({ session });

    // STEP 3: Create Settings
    const newUserSettings = new UserSettings({
      userId: savedAuth._id,
      hasSeenWelcome: false,
      isEmailVisible: true,
      isPhoneVisible: false,
    });
    await newUserSettings.save({ session });

    // STEP 4: Auto-Join Groups
    if (yearOfAttendance) {
      const classGroupName = `Class of ${yearOfAttendance}`;
      await Group.findOneAndUpdate(
        { name: classGroupName, type: "Class" },
        {
          $addToSet: { members: savedAuth._id },
          $setOnInsert: {
            description: `Official group for the ${classGroupName}`,
          },
        },
        { upsert: true, new: true, session },
      );
    }

    if (city) {
      const chapterName = `${city} Chapter`;
      await Group.findOneAndUpdate(
        { name: chapterName, type: "Chapter" },
        {
          $addToSet: { members: savedAuth._id },
          $setOnInsert: {
            description: `Official chapter for alumni in ${city}`,
          },
        },
        { upsert: true, new: true, session },
      );
    }

    // ✅ COMMIT TRANSACTION
    await session.commitTransaction();
    session.endSession();

    // 5. Post-Transaction Actions (Notifications & Socket)
    try {
      if (req.io) {
        // Notify Admin Dashboard
        req.io.emit("admin_stats_update", { type: "NEW_USER" });

        // Notify Mobile Users (Presence)
        req.io.emit("user_status_update", {
          userId: savedAuth._id,
          isOnline: true,
          lastSeen: new Date(),
        });
      }

      if (city) {
        await sendPersonalNotification(
          savedAuth._id,
          `Welcome to the ${city} Chapter!`,
          `You have been automatically added to the ${city} alumni group. Tap to say hi!`,
          { route: "chapter_chat", id: `${city} Chapter` },
        );
      }
    } catch (notifyErr) {
      console.error("Post-registration notification error:", notifyErr);
    }

    const token = jwt.sign(
      { _id: savedAuth._id, isAdmin: false, canEdit: false },
      process.env.JWT_SECRET,
      { expiresIn: "2h" },
    );

    const refreshToken = jwt.sign(
      { _id: savedAuth._id },
      process.env.REFRESH_SECRET,
      { expiresIn: "30d" },
    );

    res.status(201).json({
      message: "Registration successful!",
      token: token,
      refreshToken: refreshToken,
      user: {
        id: savedAuth._id,
        fullName: savedProfile.fullName,
        email: savedAuth.email,
        alumniId: savedProfile.alumniId,
        hasSeenWelcome: false,
      },
    });
  } catch (err) {
    // ❌ ABORT TRANSACTION ON ERROR
    await session.abortTransaction();
    session.endSession();
    throw err; // Pass error to global handler
  }
});

// --------------------------------------------------------------------------
// 2. LOGIN
// --------------------------------------------------------------------------
exports.login = asyncHandler(async (req, res) => {
  const { error } = loginSchema.validate(req.body);
  if (error) {
    res.status(400);
    throw new Error(error.details[0].message);
  }

  const { email, password, fcmToken } = req.body;

  let userAuth = await UserAuth.findOne({ email });
  if (!userAuth) {
    res.status(400);
    throw new Error("Email is not found.");
  }

  const validPass = await bcrypt.compare(password, userAuth.password);
  if (!validPass) {
    res.status(400);
    throw new Error("Invalid Password.");
  }

  if (userAuth.isVerified === false) {
    res.status(403);
    throw new Error("Account pending approval.");
  }

  const userProfile = await UserProfile.findOne({ userId: userAuth._id });
  const userSettings = await UserSettings.findOne({ userId: userAuth._id });

  if (fcmToken) {
    await manageFcmToken(userAuth._id, fcmToken);
  }

  userAuth.isOnline = true;
  userAuth.lastSeen = new Date();
  await userAuth.save();

  if (req.io) {
    req.io.emit("user_status_update", {
      userId: userAuth._id,
      isOnline: true,
      lastSeen: userAuth.lastSeen,
    });
  }

  const token = jwt.sign(
    { _id: userAuth._id, isAdmin: userAuth.isAdmin, canEdit: userAuth.canEdit },
    process.env.JWT_SECRET,
    { expiresIn: "2h" },
  );

  const refreshToken = jwt.sign(
    { _id: userAuth._id },
    process.env.REFRESH_SECRET,
    { expiresIn: "30d" },
  );

  res.json({
    token,
    refreshToken,
    user: {
      id: userAuth._id,
      fullName: userProfile.fullName,
      email: userAuth.email,
      isAdmin: userAuth.isAdmin,
      canEdit: userAuth.canEdit,
      profilePicture: userProfile.profilePicture,
      hasSeenWelcome: userSettings.hasSeenWelcome || false,
      alumniId: userProfile.alumniId,
    },
  });
});

// --------------------------------------------------------------------------
// 3. GOOGLE LOGIN
// --------------------------------------------------------------------------
exports.googleLogin = asyncHandler(async (req, res) => {
  const { token, fcmToken } = req.body;
  let name, email, picture;

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
      { headers: { Authorization: `Bearer ${token}` } },
    );
    name = response.data.name;
    email = response.data.email;
    picture = response.data.picture;
  }

  let userAuth = await UserAuth.findOne({ email });
  let userProfile, userSettings;

  if (!userAuth) {
    const currentYear = new Date().getFullYear();
    const randomPassword = crypto.randomBytes(16).toString("hex");
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(randomPassword, salt);
    const newAlumniId = await generateAlumniId(currentYear);

    userAuth = new UserAuth({
      email: email,
      password: hashedPassword,
      isVerified: true,
      provider: "google",
      fcmTokens: fcmToken ? [fcmToken] : [],
      isOnline: true,
    });
    await userAuth.save();

    userProfile = new UserProfile({
      userId: userAuth._id,
      fullName: name,
      profilePicture: picture,
      yearOfAttendance: currentYear,
      alumniId: newAlumniId,
    });
    await userProfile.save();

    userSettings = new UserSettings({
      userId: userAuth._id,
      hasSeenWelcome: false,
    });
    await userSettings.save();

    // ✅ Emit admin event for Google Signups too
    if (req.io) req.io.emit("admin_stats_update", { type: "NEW_USER" });
  } else {
    userProfile = await UserProfile.findOne({ userId: userAuth._id });
    userSettings = await UserSettings.findOne({ userId: userAuth._id });
  }

  if (!userAuth.isVerified) {
    res.status(403);
    throw new Error("Account pending approval.");
  }

  if (fcmToken) {
    await manageFcmToken(userAuth._id, fcmToken);
  }

  userAuth.isOnline = true;
  userAuth.lastSeen = new Date();
  await userAuth.save();

  if (req.io) {
    req.io.emit("user_status_update", {
      userId: userAuth._id,
      isOnline: true,
      lastSeen: userAuth.lastSeen,
    });
  }

  const authToken = jwt.sign(
    { _id: userAuth._id, isAdmin: userAuth.isAdmin, canEdit: userAuth.canEdit },
    process.env.JWT_SECRET,
    { expiresIn: "2h" },
  );

  const refreshToken = jwt.sign(
    { _id: userAuth._id },
    process.env.REFRESH_SECRET,
    { expiresIn: "30d" },
  );

  return res.json({
    token: authToken,
    refreshToken: refreshToken,
    user: {
      id: userAuth._id,
      fullName: userProfile.fullName,
      email: userAuth.email,
      isAdmin: userAuth.isAdmin,
      canEdit: userAuth.canEdit,
      profilePicture: userProfile.profilePicture,
      hasSeenWelcome: userSettings.hasSeenWelcome || false,
      alumniId: userProfile.alumniId,
    },
  });
});

// --------------------------------------------------------------------------
// 4. REFRESH TOKEN
// --------------------------------------------------------------------------
exports.refreshToken = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    res.status(401);
    throw new Error("Refresh Token Required");
  }

  try {
    const verified = jwt.verify(refreshToken, process.env.REFRESH_SECRET);
    const userAuth = await UserAuth.findById(verified._id);

    const newAccessToken = jwt.sign(
      {
        _id: userAuth._id,
        isAdmin: userAuth.isAdmin,
        canEdit: userAuth.canEdit,
      },
      process.env.JWT_SECRET,
      { expiresIn: "2h" },
    );

    res.json({ token: newAccessToken });
  } catch (err) {
    res.status(403);
    throw new Error("Invalid Refresh Token");
  }
});

// --------------------------------------------------------------------------
// 5. FORGOT PASSWORD
// --------------------------------------------------------------------------
exports.forgotPassword = asyncHandler(async (req, res) => {
  if (!req.body.email) {
    res.status(400);
    throw new Error("Email is required");
  }

  const userAuth = await UserAuth.findOne({ email: req.body.email });
  if (!userAuth) {
    res.status(400);
    throw new Error("Email not found");
  }

  const userProfile = await UserProfile.findOne({ userId: userAuth._id });

  const token = crypto.randomBytes(20).toString("hex");
  userAuth.resetPasswordToken = token;
  userAuth.resetPasswordExpires = Date.now() + 3600000;
  await userAuth.save();

  // ✅ FIX: Use Environment Variable
  const clientUrl = process.env.CLIENT_URL || "http://localhost:3000";
  const resetUrl = `${clientUrl}/reset-password?token=${token}`;

  await axios.post(
    "https://api.brevo.com/v3/smtp/email",
    {
      sender: { name: "ASCON Alumni", email: process.env.EMAIL_USER },
      to: [{ email: userAuth.email, name: userProfile.fullName }],
      subject: "ASCON Alumni - Password Reset",
      htmlContent: `
        <h3>Password Reset Request</h3>
        <p>Hello ${userProfile.fullName},</p>
        <p>You requested a password reset. Click the link below:</p>
        <p><a href="${resetUrl}">Reset Password</a></p>
      `,
    },
    {
      headers: {
        "api-key": process.env.EMAIL_PASS,
        "Content-Type": "application/json",
      },
    },
  );

  res.json({ message: "Reset link sent to your email!" });
});

// --------------------------------------------------------------------------
// 6. RESET PASSWORD EXECUTE
// --------------------------------------------------------------------------
exports.resetPassword = asyncHandler(async (req, res) => {
  const { token, newPassword } = req.body;
  if (!newPassword || newPassword.length < 6) {
    res.status(400);
    throw new Error("Password too short.");
  }

  const userAuth = await UserAuth.findOne({
    resetPasswordToken: token,
    resetPasswordExpires: { $gt: Date.now() },
  });
  if (!userAuth) {
    res.status(400);
    throw new Error("Invalid or expired token.");
  }

  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(newPassword, salt);

  userAuth.password = hashedPassword;
  userAuth.resetPasswordToken = undefined;
  userAuth.resetPasswordExpires = undefined;

  await userAuth.save();
  res.json({ message: "Password updated successfully! Please login." });
});

// --------------------------------------------------------------------------
// 7. LOGOUT
// --------------------------------------------------------------------------
exports.logout = asyncHandler(async (req, res) => {
  const { userId, fcmToken } = req.body;
  if (userId && fcmToken) {
    await UserAuth.updateOne(
      { _id: userId },
      { $pull: { fcmTokens: fcmToken } },
    );
  }
  res.status(200).json({ message: "Logged out successfully" });
});
