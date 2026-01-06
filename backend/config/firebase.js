const admin = require("firebase-admin");
const dotenv = require("dotenv");
dotenv.config();

try {
  // Decode the Base64 string back to JSON
  const serviceAccount = JSON.parse(
    Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT, "base64").toString("utf8")
  );

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log("🔥 Firebase Admin Initialized Successfully");
} catch (error) {
  console.error("❌ Firebase Admin Init Error:", error.message);
}

module.exports = admin;
