const express = require("express");
const router = express.Router();
const twilioController = require("../controllers/twilioController");

// ✅ FIX: Remove curly braces because verifyToken.js exports the function directly
const verifyToken = require("./verifyToken");

// GET /api/twilio/token - For the app to get a login token
router.get("/token", verifyToken, twilioController.getAccessToken);

// POST /api/twilio/voice - Webhook for Twilio (Public)
router.post("/voice", twilioController.voiceWebhook);

module.exports = router;
