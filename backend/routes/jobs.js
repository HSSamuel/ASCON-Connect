const router = require("express").Router();
const Job = require("../models/Job");
const verifyToken = require("./verifyToken");
const verifyAdmin = require("./verifyAdmin"); // Reuse your existing admin check
const { sendBroadcastNotification } = require("../utils/notificationHandler");

// @route   GET /api/jobs
// @desc    Get all jobs (Public)
router.get("/", async (req, res) => {
  try {
    const jobs = await Job.find().sort({ createdAt: -1 });
    
    // ✅ WRAP RESPONSE: Ensures frontend hooks like usePaginatedFetch find the list easily
    res.status(200).json({ 
      success: true, 
      count: jobs.length, 
      data: jobs 
    }); 
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// @route   POST /api/jobs
// @desc    Post a new job (Admin Only)
router.post("/", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const newJob = new Job(req.body);
    const savedJob = await newJob.save();

    // 🔔 Notify all users
    await sendBroadcastNotification(
      `New Opportunity: ${savedJob.title}`,
      `at ${savedJob.company}. Tap to view details.`,
      { route: "job_detail", id: savedJob._id.toString() }
    );

    res.status(201).json(savedJob);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// @route   PUT /api/jobs/:id
// @desc    Update a job
router.put("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    const updatedJob = await Job.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
    });
    res.json(updatedJob);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// @route   DELETE /api/jobs/:id
// @desc    Delete a job
router.delete("/:id", verifyToken, verifyAdmin, async (req, res) => {
  try {
    await Job.findByIdAndDelete(req.params.id);
    res.json({ message: "Job deleted" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
