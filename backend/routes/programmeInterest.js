const router = require("express").Router();
const ProgrammeInterest = require("../models/ProgrammeInterest");
const Programme = require("../models/Programme");

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
    // Fetch all interests and sort by Date (Newest first)
    const interests = await ProgrammeInterest.find().sort({ createdAt: -1 });
    res.json(interests);
  } catch (err) {
    console.error("Fetch Error:", err);
    res.status(500).json({ message: "Server error." });
  }
});

module.exports = router;
