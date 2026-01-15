const router = require("express").Router();
const authController = require("../controllers/authController");

// 1. Register
router.post("/register", authController.register);

// 2. Login
router.post("/login", authController.login);

// 3. Google Login
router.post("/google", authController.googleLogin);

// 4. Logout
router.post("/logout", authController.logout);

// 5. Refresh Token
router.post("/refresh", authController.refreshToken);

// 6. Forgot Password
router.post("/forgot-password", authController.forgotPassword);

// 7. Reset Password
router.post("/reset-password", authController.resetPassword);

module.exports = router;
