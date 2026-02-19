const twilio = require("twilio");
const AccessToken = twilio.jwt.AccessToken;
const VoiceGrant = AccessToken.VoiceGrant;
const logger = require("../utils/logger");

// 1. Generate Access Token for Mobile App
exports.getAccessToken = (req, res) => {
  try {
    // The user's ID will be their "Phone Number" in the Twilio system
    const identity = req.user._id.toString();

    const voiceGrant = new VoiceGrant({
      outgoingApplicationSid: process.env.TWILIO_APP_SID,
      incomingAllow: true, // Allow receiving calls
    });

    const token = new AccessToken(
      process.env.TWILIO_ACCOUNT_SID,
      process.env.TWILIO_API_KEY_SID,
      process.env.TWILIO_API_KEY_SECRET,
      { identity: identity },
    );

    token.addGrant(voiceGrant);

    res.json({
      token: token.toJwt(),
      identity: identity,
    });
  } catch (error) {
    logger.error("Twilio Token Error:", error);
    res.status(500).json({ message: "Failed to generate token" });
  }
};

// 2. Webhook: Tells Twilio how to route the call
exports.voiceWebhook = (req, res) => {
  const twiml = new twilio.twiml.VoiceResponse();
  const { To } = req.body;

  if (To) {
    // Dial the Client (the other user's App)
    const dial = twiml.dial({
      callerId: process.env.TWILIO_CALLER_ID, // Optional
      answerOnBridge: true,
    });
    dial.client(To);
  } else {
    twiml.say("Invalid call request.");
  }

  res.type("text/xml");
  res.send(twiml.toString());
};
