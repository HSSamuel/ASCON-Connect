const errorHandler = (err, req, res, next) => {
  const statusCode = res.statusCode === 200 ? 500 : res.statusCode;

  // Log the error for the developer
  console.error(`[ERROR] ${req.method} ${req.url}:`, err.message);

  res.status(statusCode).json({
    message: err.message,
    // Only show the stack trace in development mode
    stack: process.env.NODE_ENV === "production" ? null : err.stack,
  });
};

module.exports = errorHandler;
