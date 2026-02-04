const mongoose = require("mongoose");

// Schema for Comments inside a Post
const commentSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "UserAuth", required: true },
    text: { type: String, required: true, max: 500 },
  },
  { timestamps: true }
);

// Main Post Schema
const updatePostSchema = new mongoose.Schema(
  {
    // The User who posted this
    authorId: { type: mongoose.Schema.Types.ObjectId, ref: "UserAuth", required: true },

    // Content
    text: { type: String, max: 1000, default: "" },
    mediaUrl: { type: String, default: "" }, // Cloudinary Image/Video URL
    mediaType: { type: String, enum: ["image", "video", "none"], default: "none" },

    // Engagement Metrics
    likes: [{ type: mongoose.Schema.Types.ObjectId, ref: "UserAuth" }], // Array of User IDs who liked it
    comments: [commentSchema], // Array of comments

    // Admin Moderation
    isBlocked: { type: Boolean, default: false }, // Admin can set this to true to hide inappropriate posts
  },
  {
    timestamps: true, // Automatically creates 'createdAt' and 'updatedAt'
  }
);

// Indexes for faster feed loading
updatePostSchema.index({ createdAt: -1 }); // Sort by newest first
updatePostSchema.index({ authorId: 1 }); // Find a specific user's posts

module.exports = mongoose.model("UpdatePost", updatePostSchema);