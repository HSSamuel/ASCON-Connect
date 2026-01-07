const admin = require("firebase-admin");
const serviceAccount = require("../config/serviceAccountKey.json");

// Initialize Firebase Admin (if not already done)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const sendBroadcast = async (title, body, type, id) => {
  const message = {
    topic: "updates", // Matches the topic subscribed to in Flutter
    notification: {
      title: title,
      body: body,
    },
    data: {
      type: type, // e.g., "Event", "Programme"
      id: id.toString(), // ID to navigate to when clicked
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log("🚀 Notification sent successfully:", response);
  } catch (error) {
    console.error("❌ Error sending notification:", error);
  }
};

module.exports = { sendBroadcast };
