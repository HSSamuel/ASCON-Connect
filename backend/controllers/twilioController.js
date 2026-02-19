const twilio = require("twilio");
const AccessToken = twilio.jwt.AccessToken;
const VoiceGrant = AccessToken.VoiceGrant;
const logger = require("../utils/logger");
const CallLog = require("../models/CallLog"); // Added CallLog model

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
    // ✅ FIX: Removed 'callerId' entirely. 
    // Twilio rejects non-phone-number strings (like "client:user123"). 
    // For app-to-app calls, caller identity is passed natively to the client.
    const dial = twiml.dial({
      answerOnBridge: true,
    });
    
    dial.client({
        statusCallbackEvent: 'initiated ringing answered completed',
        statusCallback: `${process.env.BASE_URL}/api/twilio/events`,
        statusCallbackMethod: 'POST'
    }, To);
  } else {
    twiml.say("Invalid call request.");
  }

  res.type("text/xml");
  res.send(twiml.toString());
};

// 3. Webhook: Syncs Call State to Database (Replaces WebRTC Socket Timers)
exports.callStatusWebhook = async (req, res) => {
  const { CallSid, CallStatus, From, To, CallDuration } = req.body;

  try {
    // Twilio prefixes clients with 'client:', strip it to get User IDs
    const callerId = From ? From.replace("client:", "") : "Unknown";
    const receiverId = To ? To.replace("client:", "") : "Unknown";

    let status = "ringing";
    if (CallStatus === "in-progress") status = "ongoing";
    if (CallStatus === "completed") status = "ended";
    if (
      CallStatus === "no-answer" ||
      CallStatus === "failed" ||
      CallStatus === "canceled" ||
      CallStatus === "busy"
    )
      status = "missed";

    const updateData = {
      caller: callerId,
      receiver: receiverId,
      status: status,
      twilioCallSid: CallSid,
    };

    if (CallStatus === "completed") {
      updateData.endTime = new Date();
      updateData.duration = CallDuration || 0;
    } else if (CallStatus === "in-progress") {
      updateData.startTime = new Date();
    }

    // Upsert to ensure we capture the log regardless of which webhook fires first
    await CallLog.findOneAndUpdate({ twilioCallSid: CallSid }, updateData, {
      upsert: true,
      new: true,
      setDefaultsOnInsert: true,
    });

    res.sendStatus(200);
  } catch (error) {
    logger.error("Call Status Webhook Error:", error);
    res.sendStatus(500);
  }
};
