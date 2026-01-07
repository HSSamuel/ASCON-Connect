import React, { useEffect } from "react";
import "./Toast.css";

function Toast({ message, type = "success", onClose }) {
  // Auto-dismiss after 4 seconds
  useEffect(() => {
    const timer = setTimeout(() => {
      onClose();
    }, 4000);
    return () => clearTimeout(timer);
  }, [onClose]);

  // Dynamic Icons based on type
  const getIcon = () => {
    switch (type) {
      case "success":
        return "✅";
      case "error":
        return "❌";
      case "info":
        return "📥"; // Icon for Export
      default:
        return "🔔";
    }
  };

  return (
    <div className={`toast-container toast-${type}`}>
      <div className="toast-icon">{getIcon()}</div>
      <div className="toast-content">
        <span className="toast-message">{message}</span>
      </div>
      <button className="toast-close" onClick={onClose}>
        &times;
      </button>
    </div>
  );
}

export default Toast;
