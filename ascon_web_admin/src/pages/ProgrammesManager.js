import React, { useState } from "react";
import api from "../api"; // ✅ Import centralized API
import ProgrammesTab from "../components/ProgrammesTab";
import ConfirmModal from "../ConfirmModal";
import Toast from "../Toast";
import { usePaginatedFetch } from "../hooks/usePaginatedFetch";

// Note: usePaginatedFetch might still use raw axios if not refactored.
// For now, let's focus on the mutations (POST/PUT/DELETE) which are handled here.

function ProgrammesManager({ canEdit }) {
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const [showForm, setShowForm] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [editingId, setEditingId] = useState(null);

  const [progForm, setProgForm] = useState({
    title: "",
    description: "",
    location: "ASCON Complex, Badagry",
    duration: "",
    fee: "",
    image: "",
  });

  // Since usePaginatedFetch is a custom hook, we pass the *endpoint* only if we updated the hook.
  // Assuming the hook still expects a full URL or we haven't touched it yet,
  // we might keep the full URL string just for the fetch hook for now to avoid breaking it.
  const BASE_URL =
    process.env.REACT_APP_API_URL || "https://ascon-st50.onrender.com";
  const programmes = usePaginatedFetch(
    `${BASE_URL}/api/admin/programmes`,
    localStorage.getItem("auth_token"),
    refreshTrigger,
  );

  const showToast = (message, type = "success") => setToast({ message, type });

  const resetForm = () => {
    setEditingId(null);
    setProgForm({
      title: "",
      description: "",
      location: "ASCON Complex, Badagry",
      duration: "",
      fee: "",
      image: "",
    });
    setShowForm(false);
  };

  const sanitizePayload = (data) => {
    const { _id, id, createdAt, updatedAt, __v, code, ...cleanData } = data;
    return cleanData;
  };

  const handleProgrammeSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);

    try {
      const cleanData = sanitizePayload(progForm);

      if (editingId) {
        await api.put(`/api/admin/programmes/${editingId}`, cleanData);
        showToast("Programme updated");
      } else {
        await api.post("/api/admin/programmes", cleanData);
        showToast("Programme created");
      }
      resetForm();
      setRefreshTrigger((prev) => prev + 1);
    } catch (err) {
      console.error(err);
      showToast(
        err.response?.data?.message || "Error saving programme",
        "error",
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async () => {
    setIsSubmitting(true);
    try {
      await api.delete(`/api/admin/programmes/${deleteModal.id}`);
      showToast("Programme deleted");
      setRefreshTrigger((prev) => prev + 1);
    } catch (err) {
      showToast("Delete failed", "error");
    } finally {
      setIsSubmitting(false);
      setDeleteModal({ show: false, id: null });
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
        title="Delete Programme"
        message="Are you sure?"
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={handleDelete}
        isLoading={isSubmitting}
      />

      <ProgrammesTab
        programmesList={programmes.data}
        canEdit={canEdit}
        editingId={editingId}
        progForm={progForm}
        setProgForm={setProgForm}
        handleProgrammeSubmit={handleProgrammeSubmit}
        showForm={showForm}
        setShowForm={setShowForm}
        isSubmitting={isSubmitting}
        startEditProgramme={(prog) => {
          setEditingId(prog._id);
          setProgForm({
            title: prog.title || "",
            description: prog.description || "",
            location: prog.location || "ASCON Complex, Badagry",
            duration: prog.duration || "",
            fee: prog.fee || "",
            image: prog.image || "",
          });
          setShowForm(true);
          window.scrollTo(0, 0);
        }}
        cancelEditProgramme={resetForm}
        deleteProgrammeClick={(id) => setDeleteModal({ show: true, id })}
      />
    </div>
  );
}

export default ProgrammesManager;
