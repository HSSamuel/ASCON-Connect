const Counter = require("../models/Counter");
const crypto = require("crypto");
const logger = require("./logger"); // ✅ Import Logger

async function generateAlumniId(year) {
  const maxAttempts = 3;
  let attempt = 0;

  while (attempt < maxAttempts) {
    try {
      const currentYear = new Date().getFullYear().toString();
      const targetYear = year ? year.toString() : currentYear;
      const counterId = `alumni_id_${targetYear}`;

      const counter = await Counter.findByIdAndUpdate(
        counterId,
        { $inc: { seq: 1 } },
        { new: true, upsert: true, setDefaultsOnInsert: true }
      );

      const paddedNum = counter.seq.toString().padStart(4, "0");
      return `ASC/${targetYear}/${paddedNum}`;
    } catch (error) {
      // ✅ Log warning instead of console.error
      logger.warn(
        `Error generating Alumni ID (Attempt ${attempt + 1}): ${error.message}`
      );
      attempt++;
    }
  }

  const randomSuffix = crypto.randomBytes(2).toString("hex").toUpperCase();
  logger.error("🚨 ID Generation Failed 3 times. Using Fallback ID."); // ✅ Log critical error
  return `ASC/${new Date().getFullYear()}/FALLBACK-${randomSuffix}`;
}

module.exports = { generateAlumniId };
