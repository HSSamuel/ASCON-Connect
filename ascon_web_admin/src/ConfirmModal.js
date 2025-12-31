import React from "react";
import "./ConfirmModal.css";

const ConfirmModal = ({ isOpen, onClose, onConfirm, title, message }) => {
  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      {/* Stop click propagation so clicking inside box doesn't close it */}
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <span className="modal-icon">⚠️</span>
        <h3 className="modal-title">{title}</h3>
        <p className="modal-text">{message}</p>

        <div className="modal-actions">
          <button className="btn-cancel" onClick={onClose}>
            Cancel
          </button>
          <button className="btn-delete" onClick={onConfirm}>
            Yes, Delete
          </button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmModal;
