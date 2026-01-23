import React, { useState, useEffect, useCallback } from "react";
import api from "../api"; // ✅ Import centralized API
import { FaTrash, FaEdit, FaTimes, FaLink } from "react-icons/fa";
import "./FacilitiesTab.css";
import Toast from "../Toast";
import ConfirmModal from "../ConfirmModal";
import SkeletonTable from "./SkeletonTable";

function FacilitiesTab({ onRefreshStats }) {
  const [facilities, setFacilities] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });

  const [formData, setFormData] = useState({
    name: "",
    image: "",
    description: "",
    paymentUrl: "",
  });

  const [rates, setRates] = useState([{ type: "", naira: "", dollar: "" }]);

  // Fetch Facilities
  const fetchFacilities = useCallback(async () => {
    try {
      const res = await api.get("/api/facilities");
      setFacilities(res.data.data || []);
      setIsLoading(false);
    } catch (err) {
      console.error("Error fetching facilities:", err);
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchFacilities();
  }, [fetchFacilities]);

  const showToast = (message, type = "success") => setToast({ message, type });

  const handleInputChange = (e) =>
    setFormData({ ...formData, [e.target.name]: e.target.value });

  const handleRateChange = (index, e) => {
    const newRates = [...rates];
    newRates[index][e.target.name] = e.target.value;
    setRates(newRates);
  };

  const addRateRow = () =>
    setRates([...rates, { type: "", naira: "", dollar: "" }]);
  const removeRateRow = (index) =>
    setRates(rates.filter((_, i) => i !== index));

  const handleEdit = (facility) => {
    setEditingId(facility._id);
    setFormData({
      name: facility.name,
      image: facility.image,
      description: facility.description || "",
      paymentUrl: facility.paymentUrl || "",
    });
    setRates(facility.rates || []);
    setShowForm(true);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const toggleStatus = async (facility) => {
    try {
      const newStatus = !facility.isActive;
      await api.put(`/api/facilities/${facility._id}`, { isActive: newStatus });
      showToast(`Facility ${newStatus ? "Enabled" : "Disabled"}`, "success");
      fetchFacilities();
    } catch (err) {
      showToast("Failed to update status", "error");
    }
  };

  const confirmDelete = (id) => setDeleteModal({ show: true, id });

  const handleDelete = async () => {
    setIsSubmitting(true);
    try {
      await api.delete(`/api/facilities/${deleteModal.id}`);
      showToast("Facility Deleted Successfully!", "success");
      fetchFacilities();
      if (onRefreshStats) onRefreshStats();
    } catch (err) {
      showToast("Failed to delete facility", "error");
    } finally {
      setIsSubmitting(false);
      setDeleteModal({ show: false, id: null });
    }
  };

  const resetForm = () => {
    setShowForm(false);
    setEditingId(null);
    setFormData({ name: "", image: "", description: "", paymentUrl: "" });
    setRates([{ type: "", naira: "", dollar: "" }]);
  };

  const toggleForm = () => {
    if (showForm) resetForm();
    else setShowForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.name || !formData.image)
      return showToast("Name and Image are required!", "error");
    setIsSubmitting(true);

    try {
      if (editingId) {
        await api.put(`/api/facilities/${editingId}`, { ...formData, rates });
        showToast("Facility Updated Successfully!", "success");
      } else {
        await api.post("/api/facilities", { ...formData, rates });
        showToast("Facility Added Successfully!", "success");
      }
      resetForm();
      fetchFacilities();
      if (onRefreshStats) onRefreshStats();
    } catch (err) {
      showToast(err.response?.data?.message || "Operation failed", "error");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) return <SkeletonTable columns={5} />;

  return (
    <div className="tab-content-container">
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}
      <ConfirmModal
        isOpen={deleteModal.show}
        title="Delete Facility"
        message="Are you sure?"
        confirmText="Delete"
        isDanger={true}
        onConfirm={handleDelete}
        onCancel={() => setDeleteModal({ show: false, id: null })}
        isLoading={isSubmitting}
      />

      <div className="tab-header">
        <h2>Facility Rentals</h2>
        <button className="btn-primary" onClick={toggleForm}>
          {showForm ? "Cancel" : "+ Add New Facility"}
        </button>
      </div>

      {showForm && (
        <div className="form-card fade-in">
          <h3>{editingId ? "Edit Facility" : "Add New Facility"}</h3>
          <form onSubmit={handleSubmit}>
            <div className="form-grid">
              <input
                type="text"
                name="name"
                placeholder="Facility Name"
                value={formData.name}
                onChange={handleInputChange}
                required
              />
              <input
                type="text"
                name="image"
                placeholder="Image URL"
                value={formData.image}
                onChange={handleInputChange}
                required
              />
              <input
                type="text"
                name="paymentUrl"
                placeholder="Payment/Booking URL (Optional)"
                value={formData.paymentUrl}
                onChange={handleInputChange}
                style={{ gridColumn: "1 / -1" }}
              />
              <textarea
                name="description"
                placeholder="Description"
                value={formData.description}
                onChange={handleInputChange}
                rows="3"
                style={{
                  gridColumn: "1 / -1",
                  padding: "10px",
                  borderRadius: "6px",
                  border: "1px solid #ddd",
                  resize: "vertical",
                }}
              />
            </div>
            <div className="form-section-title">Rental Rates</div>
            <div className="rates-container">
              {rates.map((rate, index) => (
                <div key={index} className="rate-row">
                  <input
                    placeholder="Type (e.g. Daily)"
                    name="type"
                    value={rate.type}
                    onChange={(e) => handleRateChange(index, e)}
                    className="rate-input type"
                  />
                  <input
                    placeholder="₦ Amount"
                    name="naira"
                    value={rate.naira}
                    onChange={(e) => handleRateChange(index, e)}
                    className="rate-input"
                  />
                  <input
                    placeholder="$ Amount"
                    name="dollar"
                    value={rate.dollar}
                    onChange={(e) => handleRateChange(index, e)}
                    className="rate-input"
                  />
                  {rates.length > 1 && (
                    <button
                      type="button"
                      onClick={() => removeRateRow(index)}
                      className="delete-btn icon-only"
                    >
                      <FaTimes />
                    </button>
                  )}
                </div>
              ))}
              <button
                type="button"
                onClick={addRateRow}
                className="add-rate-btn"
              >
                + Add Another Rate
              </button>
            </div>
            <div className="form-actions">
              <button
                type="submit"
                className="approve-btn"
                disabled={isSubmitting}
              >
                {isSubmitting ? (
                  <>
                    <span className="loading-spinner"></span> Saving...
                  </>
                ) : editingId ? (
                  "Update Facility"
                ) : (
                  "Save Facility"
                )}
              </button>
              <button
                type="button"
                onClick={resetForm}
                className="delete-btn"
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
              <th>Image</th>
              <th>Facility Name</th>
              <th>Rates Summary</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {facilities.length > 0 ? (
              facilities.map((fac) => (
                <tr key={fac._id}>
                  <td>
                    <img
                      src={fac.image}
                      alt={fac.name}
                      className="table-thumbnail"
                    />
                  </td>
                  <td className="font-bold">
                    {fac.name}
                    {fac.paymentUrl && (
                      <FaLink
                        style={{
                          marginLeft: "8px",
                          color: "#1B5E3A",
                          fontSize: "0.8rem",
                        }}
                        title="Payment Link Active"
                      />
                    )}
                  </td>
                  <td>
                    {fac.rates && fac.rates.length > 0 ? (
                      fac.rates.map((r, i) => (
                        <div key={i} className="rate-item">
                          <span className="rate-type">{r.type}:</span>{" "}
                          <strong>₦{r.naira}</strong> / ${r.dollar}
                        </div>
                      ))
                    ) : (
                      <span className="text-muted">No rates set</span>
                    )}
                  </td>
                  <td>
                    <span
                      className={`status-badge ${fac.isActive ? "active" : "inactive"}`}
                      onClick={() => toggleStatus(fac)}
                      title="Click to toggle status"
                      style={{ cursor: "pointer" }}
                    >
                      {fac.isActive ? "Active" : "Disabled"}
                    </span>
                  </td>
                  <td>
                    <div className="action-buttons-container">
                      <button
                        onClick={() => handleEdit(fac)}
                        className="approve-btn compact-btn"
                        title="Edit"
                      >
                        <FaEdit />
                      </button>
                      <button
                        onClick={() => confirmDelete(fac._id)}
                        className="delete-btn compact-btn"
                        title="Delete"
                      >
                        <FaTrash />
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan="5" className="empty-state">
                  No facilities found. Click "Add New Facility" to create one.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default FacilitiesTab;
