const validateEnv = () => {
  const requiredEnv = [
    "PORT",
    "DB_CONNECT",
    "JWT_SECRET",
    "REFRESH_SECRET",
    "EMAIL_USER",
    "EMAIL_PASS",
    "GOOGLE_CLIENT_ID",
    "NODE_ENV",
  ];

  const missing = requiredEnv.filter((env) => !process.env[env]);

  if (missing.length > 0) {
    console.error(
      `❌ CRITICAL ERROR: Missing environment variables: ${missing.join(", ")}`,
    );
    process.exit(1);
  }

  // ✅ New Redis Validation
  if (process.env.USE_REDIS === "true" && !process.env.REDIS_URL) {
    console.warn(
      "⚠️  WARNING: Redis is enabled (USE_REDIS=true) but REDIS_URL is missing. Defaulting to localhost.",
    );
  }

  console.log(`🌍 Mode: ${process.env.NODE_ENV || "development"}`);
  console.log("✅ Environment Variables Validated");
};

module.exports = validateEnv;
