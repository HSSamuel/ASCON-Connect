import React, { useState, useEffect } from "react";
import axios from "axios";
import JobsTab from "../components/JobsTab";
import ConfirmModal from "../ConfirmModal";
import Toast from "../Toast";
import { usePaginatedFetch } from "../hooks/usePaginatedFetch";

const BASE_URL = process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

function JobsManager({ token, canEdit }) {
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });
  const [editingId, setEditingId] = useState(null);

  const [jobForm, setJobForm] = useState({
    title: "",
    company: "",
    location: "",
    type: "Full-time",
    salary: "",
    applicationLink: "",
    description: "",
  });

  // Fetch Jobs
  const jobs = usePaginatedFetch(`${BASE_URL}/api/jobs`, token);

  // Debugging: Check if data is arriving
  useEffect(() => {
    console.log("Jobs Data:", jobs.data);
  }, [jobs.data]);

  const showToast = (message, type = "success") => setToast({ message, type });

  const resetForm = () => {
    setEditingId(null);
    setJobForm({
      title: "",
      company: "",
      location: "",
      type: "Full-time",
      salary: "",
      applicationLink: "",
      description: "",
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        await axios.put(`${BASE_URL}/api/jobs/${editingId}`, jobForm, {
          headers: { "auth-token": token },
        });
        showToast("Job updated successfully");
      } else {
        await axios.post(`${BASE_URL}/api/jobs`, jobForm, {
          headers: { "auth-token": token },
        });
        showToast("Job posted successfully");
      }
      resetForm();
      jobs.refresh(); // Refresh list immediately
    } catch (err) {
      showToast("Error saving job", "error");
    }
  };

  const handleDelete = async () => {
    try {
      await axios.delete(`${BASE_URL}/api/jobs/${deleteModal.id}`, {
        headers: { "auth-token": token },
      });
      showToast("Job deleted");
      jobs.refresh();
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
        title="Delete Job"
        message="Are you sure?"
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={handleDelete}
      />

      <JobsTab
        // ✅ FIX: Default to empty array if data is loading/null
        jobsList={jobs.data || []}
        canEdit={canEdit}
        editingId={editingId}
        jobForm={jobForm}
        setJobForm={setJobForm}
        handleSubmit={handleSubmit}
        startEdit={(job) => {
          setEditingId(job._id);
          setJobForm(job);
          window.scrollTo(0, 0);
        }}
        cancelEdit={resetForm}
        deleteClick={(id) => setDeleteModal({ show: true, id })}
      />
    </div>
  );
}

export default JobsManager;
