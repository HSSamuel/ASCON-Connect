const router = require("express").Router();
const ProgrammeInterest = require("../models/ProgrammeInterest");
const Programme = require("../models/Programme");

// ✅ CRITICAL FIX: Import the verification middleware
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin");

// @route   POST /api/programme-interest
// @desc    Register interest in a programme
router.post("/", async (req, res) => {
  try {
    // 1. Destructure ALL fields
    const {
      programmeId,
      fullName,
      email,
      phone,
      sex,
      addressStreet,
      addressLine2,
      city,
      state,
      country,
      sponsoringOrganisation,
      department,
      jobTitle,
      userId,
    } = req.body;

    // 2. Validate Required Fields
    if (
      !programmeId ||
      !fullName ||
      !email ||
      !phone ||
      !sex ||
      !addressStreet ||
      !city ||
      !country ||
      !sponsoringOrganisation
    ) {
      return res
        .status(400)
        .json({ message: "Please fill all required fields." });
    }

    // 3. Get Programme Details
    const programme = await Programme.findById(programmeId);
    if (!programme)
      return res.status(404).json({ message: "Programme not found." });

    // 4. Check for duplicate (Prevent double submission)
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    const existing = await ProgrammeInterest.findOne({
      programmeId,
      email: email.toLowerCase(),
      createdAt: { $gte: startOfToday },
    });
    if (existing)
      return res
        .status(400)
        .json({ message: "You have already registered for this today." });

    // 5. Save
    const newInterest = new ProgrammeInterest({
      programmeId,
      programmeTitle: programme.title,
      fullName,
      email,
      phone,
      sex,
      addressStreet,
      addressLine2,
      city,
      state,
      country,
      sponsoringOrganisation,
      department,
      jobTitle,
      userId: userId || null,
    });

    await newInterest.save();
    res.status(201).json({ message: "Registration Submitted Successfully!" });
  } catch (err) {
    console.error("Registration Error:", err);
    res.status(500).json({ message: "Server error. Please try again." });
  }
});

// @route   GET /api/programme-interest
// @desc    Get all registrations (Newest first)
router.get("/", async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const interests = await ProgrammeInterest.find()
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await ProgrammeInterest.countDocuments();

    res.json({
      registrations: interests, // Must match frontend expectation
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error("Fetch Error:", err);
    res.status(500).json({ message: "Server error." });
  }
});

// @route   DELETE /api/programme-interest/:id
// @desc    Delete a registration (Admin Only)
router.delete("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const deleted = await ProgrammeInterest.findByIdAndDelete(req.params.id);
    if (!deleted)
      return res.status(404).json({ message: "Registration not found" });

    res.json({ message: "Registration deleted successfully." });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
