const mongoose = require("mongoose");

const callLogSchema = new mongoose.Schema(
  {
    caller: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
    },
    receiver: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserAuth",
      required: true,
    },
    // status: 'initiated', 'ringing', 'ongoing', 'ended', 'missed', 'declined'
    status: {
      type: String,
      enum: ["initiated", "ringing", "ongoing", "ended", "missed", "declined"],
      default: "initiated",
    },
    startTime: { type: Date, default: Date.now },
    endTime: { type: Date },
    duration: { type: Number, default: 0 }, // In seconds

    // Snapshot of user details at the time of call (optional but useful)
    callerName: { type: String },
    callerPic: { type: String },
    receiverName: { type: String },
    receiverPic: { type: String },
  },
  { timestamps: true },
);

module.exports = mongoose.model("CallLog", callLogSchema);
