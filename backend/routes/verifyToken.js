const jwt = require("jsonwebtoken");

module.exports = function (req, res, next) {
  const token = req.header("auth-token");
  if (!token) return res.status(401).send("Access Denied. No token provided.");

  try {
    const verified = jwt.verify(token, process.env.JWT_SECRET);
    req.user = verified; // Add the user ID to the request
    next(); // Allow them to proceed
  } catch (err) {
    res.status(400).send("Invalid Token");
  }
};
