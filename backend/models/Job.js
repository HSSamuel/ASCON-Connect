const mongoose = require("mongoose");

const jobSchema = new mongoose.Schema({
  title: { type: String, required: true, trim: true },
  company: { type: String, required: true, trim: true },
  location: { type: String, required: true }, // e.g., "Lagos (Remote)"
  type: {
    type: String,
    enum: ["Full-time", "Part-time", "Contract", "Internship", "Remote"],
    default: "Full-time",
  },
  salary: { type: String, default: "Negotiable" },
  description: { type: String, required: true },
  applicationLink: { type: String, required: true }, // Email or URL
  deadline: { type: Date },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Job", jobSchema);
