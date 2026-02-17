const logger = require("./logger");

const errorHandler = (err, req, res, next) => {
  err.statusCode = err.statusCode || 500;
  err.status = err.status || "error";

  // ✅ LOGGING: Use Winston to log essential info
  logger.error(
    `${err.statusCode} - ${err.message} - ${req.originalUrl} - ${req.method} - ${req.ip}`,
  );

  // Send structured response
  res.status(err.statusCode).json({
    success: false,
    status: err.status,
    message: err.message,
    // Only show the stack trace in development mode
    stack: process.env.NODE_ENV === "development" ? err.stack : undefined,
  });
};

module.exports = errorHandler;
