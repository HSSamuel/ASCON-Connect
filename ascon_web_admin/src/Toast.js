import React, { useEffect } from "react";
import "./Toast.css";

const Toast = ({ message, type, onClose }) => {
  useEffect(() => {
    const timer = setTimeout(() => {
      onClose();
    }, 3000);
    return () => clearTimeout(timer);
  }, [onClose]);

  return (
    <div className="toast-container">
      <div className={`toast-card ${type}`}>
        <div className="toast-icon">{type === "success" ? "✅" : "🗑️"}</div>
        <div className="toast-message">{message}</div>
        <button className="toast-close-btn" onClick={onClose}>
          &times;
        </button>
      </div>
    </div>
  );
};

export default Toast;
