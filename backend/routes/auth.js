const jwt = require("jsonwebtoken");
const router = require("express").Router();
const bcrypt = require("bcryptjs"); // Tool to encrypt passwords
const User = require("../models/User"); // Import the Schema we just created

// @route   POST /api/auth/register
// @desc    Register a new ASCON Alumnus
// @access  Public (Anyone can try to sign up)
router.post("/register", async (req, res) => {
  try {
    // 1. Deconstruct the data coming from the App
    // We expect these 4 fields as per the "Simplified Sign-Up" [cite: 17]
    const { fullName, email, password, yearOfAttendance, programmeTitle } =
      req.body;

    // 2. Check if user already exists
    const emailExist = await User.findOne({ email: email });
    if (emailExist) {
      return res.status(400).json({ message: "Email already registered." });
    }

    // 3. Security: Encrypt the Password (Hashing)
    // We add 'salt' to make it impossible to hack.
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // 4. Create the new User Object
    const newUser = new User({
      fullName: fullName,
      email: email,
      password: hashedPassword, // Store the encrypted version, NOT the real password
      yearOfAttendance: yearOfAttendance,
      programmeTitle: programmeTitle,
      isVerified: false, // [cite: 18] Important: They start as unverified!
    });

    // 5. Save to MongoDB
    const savedUser = await newUser.save();

    // 6. Send success message back to the Mobile App
    res.status(201).json({
      message: "Registration successful. Please wait for Admin approval.",
      userId: savedUser._id,
    });
  } catch (err) {
    // If the database crashes or internet fails
    res.status(500).json({ message: err.message });
  }
});

// @route   POST /api/auth/login
// @desc    Login User & Get Token
// @access  Public
router.post("/login", async (req, res) => {
  try {
    // 1. Get the data from the App
    const { email, password } = req.body;

    // 2. Check if the user exists at all
    const user = await User.findOne({ email: email });
    if (!user) {
      return res.status(400).json({ message: "Email is not found." });
    }

    // 3. Check if Password is correct
    // We compare the password they typed with the encrypted one in the DB
    const validPass = await bcrypt.compare(password, user.password);
    if (!validPass) {
      return res.status(400).json({ message: "Invalid Password." });
    }

    // 4. THE GATEKEEPER CHECK (Critical for ASCON)
    // If Admin hasn't approved them yet, STOP THEM here.
    if (user.isVerified === false) {
      return res.status(403).json({
        message: "Account pending approval. Please contact Admin.",
      });
    }

    // 5. Create and assign a Token (The "Key Card")
    // This token proves who they are for the next 1 hour
    const token = jwt.sign(
      { _id: user._id, isAdmin: false },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );

    // 6. Success! Send the token to the App
    res.header("auth-token", token).json({
      token: token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// @route   POST /api/auth/forgot-password
// @desc    Simulate sending a reset code (For testing)
router.post("/forgot-password", async (req, res) => {
  try {
    const user = await User.findOne({ email: req.body.email });
    if (!user) return res.status(400).json({ message: "Email not found" });

    // In a real app, we would email this code.
    // For now, we send it back so you can test immediately.
    res.json({ message: "Reset Authorized", userId: user._id });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// @route   POST /api/auth/reset-password
// @desc    Set the new password
router.post("/reset-password", async (req, res) => {
  try {
    const { userId, newPassword } = req.body;

    // Encrypt new password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    await User.findByIdAndUpdate(userId, { password: hashedPassword });

    res.json({ message: "Password updated successfully! Please login." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
