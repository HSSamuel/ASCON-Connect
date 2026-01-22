import React, { useState } from "react";
import axios from "axios";
import ProgrammesTab from "../components/ProgrammesTab";
import ConfirmModal from "../ConfirmModal";
import Toast from "../Toast";
import { usePaginatedFetch } from "../hooks/usePaginatedFetch";

const BASE_URL =
  process.env.REACT_APP_API_URL || "https://ascon-st50.onrender.com";

function ProgrammesManager({ token, canEdit }) {
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  // ✅ 1. NEW STATE: Controls form visibility
  const [showForm, setShowForm] = useState(false);

  const [editingId, setEditingId] = useState(null);

  // ✅ REMOVED 'code' from initial state
  const [progForm, setProgForm] = useState({
    title: "",
    description: "",
    location: "ASCON Complex, Badagry",
    duration: "",
    fee: "",
    image: "",
  });

  const programmes = usePaginatedFetch(
    `${BASE_URL}/api/admin/programmes`,
    token,
    refreshTrigger,
  );

  const showToast = (message, type = "success") => setToast({ message, type });

  const resetForm = () => {
    setEditingId(null);
    // ✅ REMOVED 'code' from reset
    setProgForm({
      title: "",
      description: "",
      location: "ASCON Complex, Badagry",
      duration: "",
      fee: "",
      image: "",
    });
    // ✅ 2. Close form when resetting/canceling
    setShowForm(false);
  };

  const sanitizePayload = (data) => {
    // Explicitly destructure to remove 'code' or other unwanted fields
    const { _id, id, createdAt, updatedAt, __v, code, ...cleanData } = data;
    return cleanData;
  };

  const handleProgrammeSubmit = async (e) => {
    e.preventDefault();
    try {
      const cleanData = sanitizePayload(progForm);

      if (editingId) {
        await axios.put(
          `${BASE_URL}/api/admin/programmes/${editingId}`,
          cleanData,
          { headers: { "auth-token": token } },
        );
        showToast("Programme updated");
      } else {
        await axios.post(`${BASE_URL}/api/admin/programmes`, cleanData, {
          headers: { "auth-token": token },
        });
        showToast("Programme created");
      }
      resetForm(); // This will now also close the form
      setRefreshTrigger((prev) => prev + 1);
    } catch (err) {
      console.error(err);
      showToast(
        err.response?.data?.message || "Error saving programme",
        "error",
      );
    }
  };

  const handleDelete = async () => {
    try {
      await axios.delete(`${BASE_URL}/api/admin/programmes/${deleteModal.id}`, {
        headers: { "auth-token": token },
      });
      showToast("Programme deleted");
      setRefreshTrigger((prev) => prev + 1);
    } catch (err) {
      showToast("Delete failed", "error");
    }
    setDeleteModal({ show: false, id: null });
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
        title="Delete Programme"
        message="Are you sure?"
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={handleDelete}
      />

      <ProgrammesTab
        programmesList={programmes.data}
        canEdit={canEdit}
        editingId={editingId}
        progForm={progForm}
        setProgForm={setProgForm}
        handleProgrammeSubmit={handleProgrammeSubmit}
        // ✅ 3. Pass visibility controls
        showForm={showForm}
        setShowForm={setShowForm}
        startEditProgramme={(prog) => {
          setEditingId(prog._id);
          // ✅ Explicitly set fields to avoid bringing back 'code' from old DB records
          setProgForm({
            title: prog.title || "",
            description: prog.description || "",
            location: prog.location || "ASCON Complex, Badagry",
            duration: prog.duration || "",
            fee: prog.fee || "",
            image: prog.image || "",
          });
          setShowForm(true); // Open form when editing
          window.scrollTo(0, 0);
        }}
        cancelEditProgramme={resetForm}
        deleteProgrammeClick={(id) => setDeleteModal({ show: true, id })}
      />
    </div>
  );
}

export default ProgrammesManager;
