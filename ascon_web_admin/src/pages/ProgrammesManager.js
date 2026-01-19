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
  // ✅ 1. Add a refresh trigger state
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  const [editingId, setEditingId] = useState(null);
  const [progForm, setProgForm] = useState({
    title: "",
    code: "",
    description: "",
    location: "ASCON Complex, Badagry",
    duration: "",
    fee: "",
    image: "",
  });

  // ✅ 2. Pass the trigger to the hook
  const programmes = usePaginatedFetch(
    `${BASE_URL}/api/admin/programmes`,
    token,
    refreshTrigger,
  );

  const showToast = (message, type = "success") => setToast({ message, type });

  const resetForm = () => {
    setEditingId(null);
    setProgForm({
      title: "",
      code: "",
      description: "",
      location: "ASCON Complex, Badagry",
      duration: "",
      fee: "",
      image: "",
    });
  };

  const sanitizePayload = (data) => {
    const { _id, id, createdAt, updatedAt, __v, ...cleanData } = data;
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
      resetForm();
      // ✅ 3. Trigger the refresh
      setRefreshTrigger((prev) => prev + 1);
    } catch (err) {
      console.error(err);
      showToast("Error saving programme", "error");
    }
  };

  const handleDelete = async () => {
    try {
      await axios.delete(`${BASE_URL}/api/admin/programmes/${deleteModal.id}`, {
        headers: { "auth-token": token },
      });
      showToast("Programme deleted");
      // ✅ 3. Trigger the refresh
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
        startEditProgramme={(prog) => {
          setEditingId(prog._id);
          setProgForm({ ...prog, image: prog.image || "" });
          window.scrollTo(0, 0);
        }}
        cancelEditProgramme={resetForm}
        deleteProgrammeClick={(id) => setDeleteModal({ show: true, id })}
      />
    </div>
  );
}

export default ProgrammesManager;
