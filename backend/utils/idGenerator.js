const Counter = require("../models/Counter");
const User = require("../models/User"); // ✅ Needed to check if users exist
const crypto = require("crypto");
const logger = require("./logger"); 

async function generateAlumniId(year) {
  const maxAttempts = 3;
  let attempt = 0;

  // 1. Determine the Target Year
  const currentYear = new Date().getFullYear().toString();
  const targetYear = year ? year.toString() : currentYear;
  const counterId = `alumni_id_${targetYear}`;

  try {
    // 🧠 SMART RESET LOGIC: 
    // Check if ANY users exist for this specific year.
    // If NO users exist (e.g., you wiped the DB), reset the counter to 0.
    const userCount = await User.countDocuments({ 
      alumniId: { $regex: `^ASC/${targetYear}/` } 
    });

    if (userCount === 0) {
      await Counter.findByIdAndUpdate(
        counterId,
        { seq: 0 }, 
        { upsert: true, new: true }
      );
      logger.info(`♻️ Database wipe detected for ${targetYear}. Counter reset to 0.`);
    }
  } catch (checkError) {
    logger.warn(`⚠️ Could not verify user count, proceeding with standard generation: ${checkError.message}`);
  }

  // 2. Standard Generation Loop
  while (attempt < maxAttempts) {
    try {
      const counter = await Counter.findByIdAndUpdate(
        counterId,
        { $inc: { seq: 1 } },
        { new: true, upsert: true, setDefaultsOnInsert: true }
      );

      const paddedNum = counter.seq.toString().padStart(4, "0");
      return `ASC/${targetYear}/${paddedNum}`; // e.g., ASC/2026/0001
    } catch (error) {
      logger.warn(
        `Error generating Alumni ID (Attempt ${attempt + 1}): ${error.message}`
      );
      attempt++;
    }
  }

  // 3. Fallback if Database is completely broken
  const randomSuffix = crypto.randomBytes(2).toString("hex").toUpperCase();
  logger.error("🚨 ID Generation Failed 3 times. Using Fallback ID."); 
  return `ASC/${new Date().getFullYear()}/FALLBACK-${randomSuffix}`;
}

module.exports = { generateAlumniId };