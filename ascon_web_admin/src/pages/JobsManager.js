import React, { useState, useEffect, useCallback } from "react";
import api from "../api"; // ✅ Import the centralized API
import {
  FaTrash,
  FaEdit,
  FaBriefcase,
  FaMapMarkerAlt,
  FaExternalLinkAlt,
  FaEnvelope,
} from "react-icons/fa";
import "./JobsManager.css";
import Toast from "../Toast";
import ConfirmModal from "../ConfirmModal";
import SkeletonTable from "../components/SkeletonTable";

function JobsManager({ canEdit }) {
  // Token prop is no longer needed for API calls!
  const [jobs, setJobs] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });

  const [jobForm, setJobForm] = useState({
    title: "",
    company: "",
    location: "",
    type: "Full-time",
    salary: "",
    description: "",
    applicationLink: "",
  });

  const showToast = (message, type = "success") => setToast({ message, type });

  const fetchJobs = useCallback(async () => {
    try {
      // ✅ CLEANER: No BASE_URL, no headers needed
      const res = await api.get("/api/jobs");
      setJobs(res.data);
      setIsLoading(false);
    } catch (err) {
      console.error("Error fetching jobs:", err);
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchJobs();
  }, [fetchJobs]);

  const handleInputChange = (e) => {
    setJobForm({ ...jobForm, [e.target.name]: e.target.value });
  };

  const resetForm = () => {
    setEditingId(null);
    setShowForm(false);
    setJobForm({
      title: "",
      company: "",
      location: "",
      type: "Full-time",
      salary: "",
      description: "",
      applicationLink: "",
    });
  };

  const handleEdit = (job) => {
    setEditingId(job._id);
    setJobForm({
      title: job.title,
      company: job.company,
      location: job.location,
      type: job.type,
      salary: job.salary,
      description: job.description,
      applicationLink: job.applicationLink || "",
    });
    setShowForm(true);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);

    try {
      if (editingId) {
        // ✅ CLEANER PUT
        await api.put(`/api/jobs/${editingId}`, jobForm);
        showToast("Job updated successfully");
      } else {
        // ✅ CLEANER POST
        await api.post("/api/jobs", jobForm);
        showToast("Job posted successfully");
      }
      resetForm();
      fetchJobs();
    } catch (err) {
      showToast(err.response?.data?.message || "Error saving job", "error");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async () => {
    setIsSubmitting(true);
    try {
      // ✅ CLEANER DELETE
      await api.delete(`/api/jobs/${deleteModal.id}`);
      showToast("Job deleted successfully");
      fetchJobs();
    } catch (err) {
      showToast("Delete failed", "error");
    } finally {
      setIsSubmitting(false);
      setDeleteModal({ show: false, id: null });
    }
  };

  const getLinkType = (link) => {
    if (!link) return null;
    if (link.includes("@") && !link.startsWith("http")) return "email";
    return "url";
  };

  if (isLoading) return <SkeletonTable columns={6} />;

  return (
    <div className="jobs-container">
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
        message="Are you sure you want to delete this job posting?"
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={handleDelete}
        isLoading={isSubmitting}
      />

      <div className="table-header">
        <h2>Job Opportunities</h2>
        {canEdit && (
          <button
            className="add-btn"
            onClick={() => {
              resetForm();
              setShowForm(!showForm);
            }}
          >
            {showForm ? "Close Form" : "+ Post New Job"}
          </button>
        )}
      </div>

      {showForm && (
        <div className="form-card fade-in">
          <h3>{editingId ? "Edit Job" : "Post New Job"}</h3>
          <form onSubmit={handleSubmit}>
            <div className="form-grid">
              <input
                type="text"
                name="title"
                placeholder="Job Title"
                value={jobForm.title}
                onChange={handleInputChange}
                required
              />
              <input
                type="text"
                name="company"
                placeholder="Company Name"
                value={jobForm.company}
                onChange={handleInputChange}
                required
              />
              <select
                name="type"
                value={jobForm.type}
                onChange={handleInputChange}
              >
                <option value="Full-time">Full-time</option>
                <option value="Part-time">Part-time</option>
                <option value="Contract">Contract</option>
                <option value="Remote">Remote</option>
                <option value="Internship">Internship</option>
              </select>
              <input
                type="text"
                name="location"
                placeholder="Location (City, Country or Remote)"
                value={jobForm.location}
                onChange={handleInputChange}
                required
              />
              <input
                type="text"
                name="salary"
                placeholder="Salary Range (e.g. 150k - 200k)"
                value={jobForm.salary}
                onChange={handleInputChange}
              />
              <input
                type="text"
                name="applicationLink"
                placeholder="Application Link (URL or Email Address)"
                value={jobForm.applicationLink}
                onChange={handleInputChange}
                required
              />
              <textarea
                name="description"
                placeholder="Job Description"
                value={jobForm.description}
                onChange={handleInputChange}
                rows="4"
                style={{ gridColumn: "1 / -1" }}
                required
              />
            </div>
            <div className="form-actions">
              <button
                type="submit"
                className="save-btn"
                disabled={isSubmitting}
              >
                {isSubmitting ? (
                  <>
                    <span className="loading-spinner"></span> Saving...
                  </>
                ) : editingId ? (
                  "Update Job"
                ) : (
                  "Post Job"
                )}
              </button>
              <button
                type="button"
                onClick={resetForm}
                className="cancel-btn"
                disabled={isSubmitting}
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Title</th>
              <th>Company</th>
              <th>Type</th>
              <th>Location</th>
              <th>Link Type</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {jobs.length > 0 ? (
              jobs.map((job) => {
                const linkType = getLinkType(job.applicationLink);
                return (
                  <tr key={job._id}>
                    <td className="font-bold">{job.title}</td>
                    <td>
                      <FaBriefcase style={{ marginRight: 5, color: "#888" }} />
                      {job.company}
                    </td>
                    <td>
                      <span className="job-type-badge">{job.type}</span>
                    </td>
                    <td>
                      <FaMapMarkerAlt
                        style={{ marginRight: 5, color: "#888" }}
                      />
                      {job.location}
                    </td>
                    <td>
                      {linkType === "email" ? (
                        <a
                          href={`mailto:${job.applicationLink}`}
                          className="link-badge email"
                        >
                          <FaEnvelope /> Email
                        </a>
                      ) : (
                        <a
                          href={job.applicationLink}
                          target="_blank"
                          rel="noreferrer"
                          className="link-badge web"
                        >
                          <FaExternalLinkAlt /> Website
                        </a>
                      )}
                    </td>
                    <td>
                      {canEdit && (
                        <div className="action-buttons-container">
                          <button
                            onClick={() => handleEdit(job)}
                            className="edit-btn compact-btn"
                            title="Edit"
                          >
                            <FaEdit />
                          </button>
                          <button
                            onClick={() =>
                              setDeleteModal({ show: true, id: job._id })
                            }
                            className="delete-btn compact-btn"
                            title="Delete"
                          >
                            <FaTrash />
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })
            ) : (
              <tr>
                <td colSpan="6" className="empty-state">
                  No job postings found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default JobsManager;
