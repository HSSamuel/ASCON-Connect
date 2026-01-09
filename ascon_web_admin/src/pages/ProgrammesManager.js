import React, { useState } from "react";
import axios from "axios";
import ProgrammesTab from "../components/ProgrammesTab";
import ConfirmModal from "../ConfirmModal";
import Toast from "../Toast";
import { usePaginatedFetch } from "../hooks/usePaginatedFetch";

const BASE_URL = process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

function ProgrammesManager({ token, canEdit }) {
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });

  const [editingId, setEditingId] = useState(null);
  const [progForm, setProgForm] = useState({
    title: "",
    code: "",
    description: "",
    location: "ASCON Complex, Badagry", // ✅ ADDED: Default location
    duration: "",
    fee: "",
    image: "",
  });

  const programmes = usePaginatedFetch(
    `${BASE_URL}/api/admin/programmes`,
    token
  );

  const showToast = (message, type = "success") => setToast({ message, type });

  const resetForm = () => {
    setEditingId(null);
    // ✅ ADDED: location reset
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

  const handleProgrammeSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        await axios.put(
          `${BASE_URL}/api/admin/programmes/${editingId}`,
          progForm,
          {
            headers: { "auth-token": token },
          }
        );
        showToast("Programme updated");
      } else {
        await axios.post(`${BASE_URL}/api/admin/programmes`, progForm, {
          headers: { "auth-token": token },
        });
        showToast("Programme created");
      }
      resetForm();
      programmes.refresh();
    } catch (err) {
      showToast("Error saving programme", "error");
    }
  };

  const handleDelete = async () => {
    try {
      await axios.delete(`${BASE_URL}/api/admin/programmes/${deleteModal.id}`, {
        headers: { "auth-token": token },
      });
      showToast("Programme deleted");
      programmes.refresh();
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
