import React, { useState, useEffect, useCallback } from "react";
import axios from "axios";
import {
  FaTrash,
  FaEdit,
  FaCheckCircle,
  FaTimesCircle,
  FaFileExcel,
  FaCalendarAlt,
  FaExclamationTriangle,
  FaMapMarkerAlt,
} from "react-icons/fa";
// Ensure you have this CSS file or add the styles to your global CSS
import "./EventsManager.css";
import Toast from "../Toast";
import ConfirmModal from "../ConfirmModal";
import * as XLSX from "xlsx";
import SkeletonTable from "../components/SkeletonTable";

const BASE_URL = process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

function EventsManager({ token, canEdit }) {
  // ==========================
  // 1. STATE MANAGEMENT
  // ==========================
  const [events, setEvents] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);

  // UI Feedback
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });

  // Form State (Includes Location)
  const [eventForm, setEventForm] = useState({
    title: "",
    description: "",
    type: "News",
    image: "",
    location: "",
    date: "",
  });

  const showToast = (message, type = "success") => setToast({ message, type });

  // ==========================
  // 2. DATA FETCHING
  // ==========================
  const fetchEvents = useCallback(async () => {
    try {
      const res = await axios.get(`${BASE_URL}/api/events`);
      // Handle various response structures
      const data = Array.isArray(res.data)
        ? res.data
        : res.data.events || res.data.data || [];
      setEvents(data);
      setIsLoading(false);
    } catch (err) {
      console.error("Error fetching events:", err);
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchEvents();
  }, [fetchEvents]);

  // ==========================
  // 3. FORM HANDLERS
  // ==========================
  const handleInputChange = (e) => {
    setEventForm({ ...eventForm, [e.target.name]: e.target.value });
  };

  const resetForm = () => {
    setEditingId(null);
    setShowForm(false);
    setEventForm({
      title: "",
      description: "",
      type: "News",
      image: "",
      location: "",
      date: "",
    });
  };

  const handleEdit = (event) => {
    setEditingId(event._id);
    setEventForm({
      title: event.title,
      description: event.description,
      type: event.type,
      image: event.image || "",
      location: event.location || "",
      // Format date for HTML date input (YYYY-MM-DD)
      date: event.date ? new Date(event.date).toISOString().split("T")[0] : "",
    });
    setShowForm(true);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (eventForm.title.length < 5)
      return showToast("Title must be at least 5 chars", "error");

    try {
      const payload = { ...eventForm };
      // Ensure date is present
      if (!payload.date) payload.date = new Date();

      if (editingId) {
        await axios.put(`${BASE_URL}/api/admin/events/${editingId}`, payload, {
          headers: { "auth-token": token },
        });
        showToast("Event updated successfully");
      } else {
        await axios.post(`${BASE_URL}/api/admin/events`, payload, {
          headers: { "auth-token": token },
        });
        showToast("Event created successfully");
      }
      resetForm();
      fetchEvents();
    } catch (err) {
      console.error(err);
      showToast(err.response?.data?.message || "Error saving event", "error");
    }
  };

  // ==========================
  // 4. DELETE LOGIC
  // ==========================
  const handleDelete = async () => {
    try {
      await axios.delete(`${BASE_URL}/api/admin/events/${deleteModal.id}`, {
        headers: { "auth-token": token },
      });
      showToast("Event deleted successfully");
      fetchEvents();
    } catch (err) {
      showToast("Delete failed", "error");
    }
    setDeleteModal({ show: false, id: null });
  };

  const exportToExcel = () => {
    const worksheet = XLSX.utils.json_to_sheet(events);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, "Events");
    XLSX.writeFile(workbook, "ASCON_Events.xlsx");
  };

  // ==========================
  // 5. RENDER HELPERS
  // ==========================

  // Style for the new Image Column
  const thumbnailStyle = {
    width: "60px",
    height: "40px",
    objectFit: "cover",
    borderRadius: "4px",
    boxShadow: "0 2px 4px rgba(0,0,0,0.1)",
    backgroundColor: "#eee",
  };

  if (isLoading) return <SkeletonTable columns={7} />;

  return (
    <div className="events-container">
      {/* Toast Notification */}
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}

      {/* Delete Confirmation */}
      <ConfirmModal
        isOpen={deleteModal.show}
        title="Delete Event"
        message="Are you sure? This cannot be undone."
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={handleDelete}
      />

      {/* Header & Actions */}
      <div className="table-header">
        <h2>Events Management</h2>
        <div className="header-actions">
          <button className="export-btn" onClick={exportToExcel}>
            <FaFileExcel /> Export
          </button>
          {canEdit && (
            <button
              className="add-btn"
              onClick={() => {
                resetForm();
                setShowForm(!showForm);
              }}
            >
              {showForm ? "Close Form" : "+ Add New Event"}
            </button>
          )}
        </div>
      </div>

      {/* Form Section */}
      {showForm && (
        <div className="form-card fade-in">
          <h3>{editingId ? "Edit Event" : "Create New Event"}</h3>
          <form onSubmit={handleSubmit}>
            <div className="form-grid">
              <input
                type="text"
                name="title"
                placeholder="Event Title"
                value={eventForm.title}
                onChange={handleInputChange}
                required
              />
              <select
                name="type"
                value={eventForm.type}
                onChange={handleInputChange}
              >
                <option value="News">News</option>
                <option value="Event">Event</option>
                <option value="Webinar">Webinar</option>
                <option value="Reunion">Reunion</option>
                <option value="Conference">Conference</option>
                <option value="Workshop">Workshop</option>
              </select>
              <input
                type="date"
                name="date"
                value={eventForm.date}
                onChange={handleInputChange}
                required
              />
              <input
                type="text"
                name="location"
                placeholder="Location (e.g. ASCON Complex)"
                value={eventForm.location}
                onChange={handleInputChange}
              />
              <input
                type="text"
                name="image"
                placeholder="Image URL"
                value={eventForm.image}
                onChange={handleInputChange}
                style={{ gridColumn: "1 / -1" }}
              />
              <textarea
                name="description"
                placeholder="Event Description"
                value={eventForm.description}
                onChange={handleInputChange}
                rows="3"
                required
                style={{ gridColumn: "1 / -1" }}
              />
            </div>
            <div className="form-actions">
              <button type="submit" className="save-btn">
                {editingId ? "Update Event" : "Save Event"}
              </button>
              <button type="button" onClick={resetForm} className="cancel-btn">
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Events Table */}
      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Image</th> {/* ✅ 1. Added Image Column */}
              <th>Title</th>
              <th>Type</th>
              <th>Date</th>
              <th>Location</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {events.length > 0 ? (
              events.map((event) => {
                // Status Logic
                const eventDate = new Date(event.date);
                const today = new Date();
                today.setHours(0, 0, 0, 0);
                const timeDiff = eventDate.getTime() - today.getTime();
                const daysDiff = Math.ceil(timeDiff / (1000 * 3600 * 24));

                let status;
                if (daysDiff < 0) {
                  status = {
                    label: "Past",
                    class: "status-past",
                    icon: <FaTimesCircle />,
                  };
                } else if (daysDiff === 0) {
                  status = {
                    label: "Today",
                    class: "status-today",
                    icon: <FaCheckCircle />,
                  };
                } else if (daysDiff <= 7) {
                  status = {
                    label: "Upcoming",
                    class: "status-upcoming",
                    icon: <FaExclamationTriangle />,
                  };
                } else {
                  status = {
                    label: "Scheduled",
                    class: "status-scheduled",
                    icon: <FaCalendarAlt />,
                  };
                }

                return (
                  <tr key={event._id}>
                    {/* ✅ 2. Render Image Thumbnail */}
                    <td>
                      <img
                        src={event.image}
                        alt={event.title}
                        style={thumbnailStyle}
                        onError={(e) => {
                          e.target.onerror = null;
                          e.target.src =
                            "https://via.placeholder.com/60x40?text=No+Img";
                        }}
                      />
                    </td>
                    <td className="font-bold">{event.title}</td>
                    <td>
                      <span className="event-type-badge">{event.type}</span>
                    </td>
                    <td>
                      {eventDate.toLocaleDateString("en-GB", {
                        day: "2-digit",
                        month: "short",
                        year: "numeric",
                      })}
                    </td>
                    <td className="text-muted">
                      {event.location ? (
                        <>
                          <FaMapMarkerAlt style={{ marginRight: 4 }} />
                          {event.location}
                        </>
                      ) : (
                        "Online / TBD"
                      )}
                    </td>
                    <td>
                      <span className={`status-badge ${status.class}`}>
                        {status.icon} {status.label}
                      </span>
                    </td>
                    <td>
                      {canEdit && (
                        <div className="action-buttons-container">
                          <button
                            onClick={() => handleEdit(event)}
                            className="edit-btn compact-btn"
                            title="Edit"
                          >
                            <FaEdit />
                          </button>
                          <button
                            onClick={() =>
                              setDeleteModal({ show: true, id: event._id })
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
                <td colSpan="7" className="empty-state">
                  No events found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default EventsManager;
