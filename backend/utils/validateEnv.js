const validateEnv = () => {
  const requiredEnv = [
    "DB_CONNECT",
    "JWT_SECRET",
    "REFRESH_SECRET",
    "EMAIL_USER",
    "EMAIL_PASS",
    "GOOGLE_CLIENT_ID",
  ];

  const missing = requiredEnv.filter((env) => !process.env[env]);

  if (missing.length > 0) {
    console.error(
      `❌ CRITICAL ERROR: Missing environment variables: ${missing.join(", ")}`
    );
    console.error("Please check your .env file or hosting provider settings.");
    process.exit(1); // Stop the server immediately
  }

  // ✅ Optional: Log the status of NODE_ENV
  if (!process.env.NODE_ENV) {
    console.warn(
      "⚠️  WARNING: NODE_ENV is not set. Defaulting to development mode."
    );
  } else {
    console.log(`🌍 Mode: ${process.env.NODE_ENV}`);
  }

  console.log("✅ All Required Environment Variables Validated");
};

module.exports = validateEnv;
