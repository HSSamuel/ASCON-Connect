import React, { useState } from "react";
import axios from "axios";
import RegistrationsTab from "../components/RegistrationsTab";
import ConfirmModal from "../ConfirmModal";
import Toast from "../Toast";
import { usePaginatedFetch } from "../hooks/usePaginatedFetch";

const BASE_URL = process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

function RegistrationsManager({ token, canEdit }) {
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({
    show: false,
    id: null,
    type: null,
  });

  // ✅ 1. FETCH DATA (Both endpoints)
  const progRegs = usePaginatedFetch(
    `${BASE_URL}/api/programme-interest`,
    token
  );
  const eventRegs = usePaginatedFetch(
    `${BASE_URL}/api/event-registration`,
    token
  );

  const showToast = (message, type = "success") => setToast({ message, type });

  // --- ACTIONS ---
  const confirmDelete = (id, type) => {
    // 'type' comes from the Tab component as "programmes" or "events"
    // We map it to our internal API types
    const deleteType = type === "programmes" ? "reg_prog" : "reg_event";
    setDeleteModal({ show: true, id, type: deleteType });
  };

  const handleDelete = async () => {
    const { id, type } = deleteModal;
    setDeleteModal({ show: false, id: null, type: null });

    try {
      if (type === "reg_prog") {
        await axios.delete(`${BASE_URL}/api/programme-interest/${id}`, {
          headers: { "auth-token": token },
        });
        progRegs.refresh();
      } else {
        await axios.delete(`${BASE_URL}/api/event-registration/${id}`, {
          headers: { "auth-token": token },
        });
        eventRegs.refresh();
      }
      showToast("Registration deleted");
    } catch (err) {
      showToast("Delete failed", "error");
    }
  };

  return (
    <div className="manager-container">
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}

      <ConfirmModal
        isOpen={deleteModal.show}
        title="Delete Registration"
        message="Are you sure? This cannot be undone."
        onClose={() => setDeleteModal({ show: false, id: null, type: null })}
        onConfirm={handleDelete}
      />

      <RegistrationsTab
        registrations={progRegs.data}
        eventRegistrations={eventRegs.data}
        isLoading={progRegs.loading || eventRegs.loading}
        onDelete={confirmDelete}
        canEdit={canEdit}
        showToast={showToast}
      />
    </div>
  );
}

export default RegistrationsManager;
