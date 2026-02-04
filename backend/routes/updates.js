const router = require("express").Router();
const mongoose = require("mongoose");
const UpdatePost = require("../models/UpdatePost");
const UserProfile = require("../models/UserProfile");
const verifyToken = require("./verifyToken");
const upload = require("../config/cloudinary");

// =========================================================
// 1. CREATE A NEW UPDATE (Text + Optional Image)
// =========================================================
router.post("/", verifyToken, upload.single("media"), async (req, res) => {
  try {
    const { text } = req.body;
    let mediaUrl = "";
    let mediaType = "none";

    // If an image was uploaded, get the Cloudinary URL
    if (req.file) {
      mediaUrl = req.file.path;
      mediaType = "image"; // Expandable to "video" later
    }

    if (!text && !mediaUrl) {
      return res.status(400).json({ message: "Post cannot be empty." });
    }

    const newPost = new UpdatePost({
      authorId: req.user._id,
      text: text || "",
      mediaUrl,
      mediaType,
    });

    const savedPost = await newPost.save();

    // Fetch the author's profile to return the complete object immediately to the UI
    const authorProfile = await UserProfile.findOne({ userId: req.user._id });

    res.status(201).json({
      success: true,
      data: {
        ...savedPost.toObject(),
        author: {
          fullName: authorProfile.fullName,
          profilePicture: authorProfile.profilePicture,
          jobTitle: authorProfile.jobTitle,
        },
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 2. GET FEED (Fetch all updates)
// =========================================================
router.get("/", verifyToken, async (req, res) => {
  try {
    // 1. Fetch posts that are NOT blocked by admin
    const posts = await UpdatePost.find({ isBlocked: false })
      .sort({ createdAt: -1 }) // Newest first
      .limit(50) // Limit for performance (can add pagination later)
      .lean();

    // 2. Attach Author Profile Data efficiently
    const authorIds = posts.map((post) => post.authorId);
    const profiles = await UserProfile.find({
      userId: { $in: authorIds },
    }).lean();

    // Create a lookup map for instant profile matching
    const profileMap = {};
    profiles.forEach((p) => {
      profileMap[p.userId.toString()] = p;
    });

    // Merge post with author data
    const feed = posts.map((post) => {
      const author = profileMap[post.authorId.toString()] || {};
      return {
        ...post,
        author: {
          _id: author.userId,
          fullName: author.fullName || "Unknown Alumni",
          profilePicture: author.profilePicture || "",
          jobTitle: author.jobTitle || "Alumni",
        },
        // Add a flag so the frontend knows if the current user liked this
        isLikedByMe: post.likes.some(
          (id) => id.toString() === req.user._id.toString(),
        ),
      };
    });

    res.status(200).json({ success: true, data: feed });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 3. LIKE / UNLIKE A POST
// =========================================================
router.put("/:id/like", verifyToken, async (req, res) => {
  try {
    const post = await UpdatePost.findById(req.params.id);
    if (!post) return res.status(404).json({ message: "Post not found" });

    const userId = req.user._id;
    const hasLiked = post.likes.includes(userId);

    if (hasLiked) {
      // Unlike: Remove user ID from array
      post.likes = post.likes.filter(
        (id) => id.toString() !== userId.toString(),
      );
    } else {
      // Like: Add user ID to array
      post.likes.push(userId);
    }

    await post.save();
    res
      .status(200)
      .json({
        success: true,
        likesCount: post.likes.length,
        isLikedByMe: !hasLiked,
      });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 4. ADD COMMENT
// =========================================================
router.post("/:id/comment", verifyToken, async (req, res) => {
  try {
    const { text } = req.body;
    if (!text)
      return res.status(400).json({ message: "Comment cannot be empty" });

    const post = await UpdatePost.findById(req.params.id);
    if (!post) return res.status(404).json({ message: "Post not found" });

    const newComment = {
      userId: req.user._id,
      text,
      createdAt: new Date(),
    };

    post.comments.push(newComment);
    await post.save();

    // Return profile info for real-time frontend update
    const profile = await UserProfile.findOne({ userId: req.user._id });

    res.status(201).json({
      success: true,
      comment: {
        ...newComment,
        author: {
          fullName: profile.fullName,
          profilePicture: profile.profilePicture,
        },
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 5. DELETE A POST (User or Admin)
// =========================================================
router.delete("/:id", verifyToken, async (req, res) => {
  try {
    const post = await UpdatePost.findById(req.params.id);
    if (!post) return res.status(404).json({ message: "Post not found" });

    // Check permissions: Only the author OR an Admin can delete
    if (
      post.authorId.toString() !== req.user._id.toString() &&
      !req.user.isAdmin
    ) {
      return res
        .status(403)
        .json({ message: "You are not authorized to delete this post." });
    }

    await UpdatePost.findByIdAndDelete(req.params.id);
    res
      .status(200)
      .json({ success: true, message: "Post deleted successfully" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
