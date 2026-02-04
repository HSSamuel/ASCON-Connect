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

    if (req.file) {
      mediaUrl = req.file.path;
      mediaType = "image";
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
    const authorProfile = await UserProfile.findOne({ userId: req.user._id });

    res.status(201).json({
      success: true,
      data: {
        ...savedPost.toObject(),
        author: {
          fullName: authorProfile?.fullName || "User",
          profilePicture: authorProfile?.profilePicture || "",
          jobTitle: authorProfile?.jobTitle || "Member",
        },
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 2. GET FEED (Optimized)
// =========================================================
router.get("/", verifyToken, async (req, res) => {
  try {
    const posts = await UpdatePost.find({ isBlocked: false })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    const authorIds = posts.map((post) => post.authorId);
    const profiles = await UserProfile.find({
      userId: { $in: authorIds },
    }).lean();

    const profileMap = {};
    profiles.forEach((p) => {
      profileMap[p.userId.toString()] = p;
    });

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
        isLikedByMe: post.likes
          ? post.likes.some((id) => id.toString() === req.user._id.toString())
          : false,
      };
    });

    res.status(200).json({ success: true, data: feed });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 3. GET SINGLE POST (Detailed with Populated Comments)
// =========================================================
router.get("/:id", verifyToken, async (req, res) => {
  try {
    const post = await UpdatePost.findById(req.params.id).lean();
    if (!post) return res.status(404).json({ message: "Post not found" });

    // 1. Fetch Post Author
    const postAuthor = await UserProfile.findOne({
      userId: post.authorId,
    }).lean();

    // 2. Fetch Comment Authors
    // ✅ FIX: Handle empty/null comments safely
    const commentsList = post.comments || [];
    const commentUserIds = commentsList.map((c) => c.userId);
    const commentProfiles = await UserProfile.find({
      userId: { $in: commentUserIds },
    }).lean();

    const commentProfileMap = {};
    commentProfiles.forEach((p) => {
      commentProfileMap[p.userId.toString()] = p;
    });

    // 3. Construct Response
    const detailedPost = {
      ...post,
      author: {
        fullName: postAuthor?.fullName || "Unknown",
        profilePicture: postAuthor?.profilePicture || "",
        jobTitle: postAuthor?.jobTitle || "Member",
      },
      isLikedByMe: post.likes
        ? post.likes.some((id) => id.toString() === req.user._id.toString())
        : false,
      comments: commentsList.map((c) => {
        const cAuth = commentProfileMap[c.userId.toString()] || {};
        return {
          ...c,
          author: {
            fullName: cAuth.fullName || "Unknown",
            profilePicture: cAuth.profilePicture || "",
          },
        };
      }),
    };

    res.json({ success: true, data: detailedPost });
  } catch (err) {
    console.error("Single Post Error:", err);
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 4. LIKE / UNLIKE
// =========================================================
router.put("/:id/like", verifyToken, async (req, res) => {
  try {
    const post = await UpdatePost.findById(req.params.id);
    if (!post) return res.status(404).json({ message: "Post not found" });

    const userId = req.user._id;
    const hasLiked = post.likes.includes(userId);

    if (hasLiked) {
      post.likes = post.likes.filter(
        (id) => id.toString() !== userId.toString(),
      );
    } else {
      post.likes.push(userId);
    }

    await post.save();
    res.status(200).json({
      success: true,
      likesCount: post.likes.length,
      isLikedByMe: !hasLiked,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 5. ADD COMMENT
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

    const profile = await UserProfile.findOne({ userId: req.user._id });

    // Return the formatted comment so UI can display it instantly
    res.status(201).json({
      success: true,
      comment: {
        ...newComment,
        // ✅ CRITICAL: Ensure `_id` matches what frontend expects (Mongoose subdoc ID)
        _id: post.comments[post.comments.length - 1]._id,
        author: {
          fullName: profile?.fullName || "Me",
          profilePicture: profile?.profilePicture || "",
        },
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// =========================================================
// 6. DELETE POST
// =========================================================
router.delete("/:id", verifyToken, async (req, res) => {
  try {
    const post = await UpdatePost.findById(req.params.id);
    if (!post) return res.status(404).json({ message: "Post not found" });

    if (
      post.authorId.toString() !== req.user._id.toString() &&
      !req.user.isAdmin
    ) {
      return res.status(403).json({ message: "Unauthorized" });
    }

    await UpdatePost.findByIdAndDelete(req.params.id);
    res.status(200).json({ success: true, message: "Deleted" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;