import React, { useState, useEffect, useCallback, useRef } from "react"; // ✅ Import useRef
import api from "../api";
import {
  FaTrash,
  FaEdit,
  FaCheckCircle,
  FaTimesCircle,
  FaFileExcel,
  FaCalendarAlt,
  FaExclamationTriangle,
  FaMapMarkerAlt,
  FaClock,
} from "react-icons/fa";
import "./EventsManager.css";
import Toast from "../Toast";
import ConfirmModal from "../ConfirmModal";
import * as XLSX from "xlsx";
import SkeletonTable from "../components/SkeletonTable";

function EventsManager({ canEdit }) {
  const [events, setEvents] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });

  // ✅ Create a Ref for the description textarea
  const descriptionRef = useRef(null);

  const [eventForm, setEventForm] = useState({
    title: "",
    description: "",
    type: "News",
    image: "",
    location: "",
    date: "",
    time: "",
  });

  const showToast = (message, type = "success") => setToast({ message, type });

  const fetchEvents = useCallback(async () => {
    try {
      const res = await api.get("/api/events");
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

  // ✅ Auto-Resize Logic inside Input Change
  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setEventForm({ ...eventForm, [name]: value });

    // If typing in Description, auto-adjust height
    if (name === "description" && e.target) {
      e.target.style.height = "auto"; // Reset to calculate shrink
      e.target.style.height = e.target.scrollHeight + "px"; // Set to scroll height
    }
  };

  // ✅ Effect to Resize Textarea on Form Open / Data Load
  useEffect(() => {
    if (showForm && descriptionRef.current) {
      descriptionRef.current.style.height = "auto";
      descriptionRef.current.style.height =
        descriptionRef.current.scrollHeight + "px";
    }
  }, [showForm, eventForm.description]);

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
      time: "",
    });
  };

  // ... (Keep handleEdit, handleSubmit, handleDelete, exportToExcel exactly the same) ...
  const handleEdit = (event) => {
    setEditingId(event._id);
    setEventForm({
      title: event.title,
      description: event.description,
      type: event.type,
      image: event.image || "",
      location: event.location || "",
      date: event.date ? new Date(event.date).toISOString().split("T")[0] : "",
      time: event.time || "",
    });
    setShowForm(true);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (eventForm.title.length < 5)
      return showToast("Title must be at least 5 chars", "error");
    setIsSubmitting(true);

    try {
      const payload = { ...eventForm };
      if (!payload.date) payload.date = new Date();

      if (editingId) {
        await api.put(`/api/admin/events/${editingId}`, payload);
        showToast("Event updated successfully");
      } else {
        await api.post("/api/admin/events", payload);
        showToast("Event created successfully");
      }
      resetForm();
      fetchEvents();
    } catch (err) {
      showToast(err.response?.data?.message || "Error saving event", "error");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async () => {
    setIsSubmitting(true);
    try {
      await api.delete(`/api/admin/events/${deleteModal.id}`);
      showToast("Event deleted successfully");
      fetchEvents();
    } catch (err) {
      showToast("Delete failed", "error");
    } finally {
      setIsSubmitting(false);
      setDeleteModal({ show: false, id: null });
    }
  };

  const exportToExcel = () => {
    const worksheet = XLSX.utils.json_to_sheet(events);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, "Events");
    XLSX.writeFile(workbook, "ASCON_Events.xlsx");
  };

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
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}
      <ConfirmModal
        isOpen={deleteModal.show}
        title="Delete Event"
        message="Are you sure? This cannot be undone."
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={handleDelete}
        isLoading={isSubmitting}
      />

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
                <option value="Seminar">Seminar</option>
                <option value="Conference">Conference</option>
                <option value="Workshop">Workshop</option>
                <option value="Symposium">Symposium</option>
                <option value="AGM">AGM</option>
                <option value="Induction">Induction</option>
              </select>
              <div style={{ display: "flex", gap: "10px" }}>
                <input
                  type="date"
                  name="date"
                  value={eventForm.date}
                  onChange={handleInputChange}
                  required
                  style={{ flex: 1 }}
                />
                <input
                  type="text"
                  name="time"
                  placeholder="Time (e.g. 10:00 AM)"
                  value={eventForm.time}
                  onChange={handleInputChange}
                  style={{ flex: 1 }}
                />
              </div>
              <input
                type="text"
                name="location"
                placeholder="Location"
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
              {/* ✅ UPDATED TEXTAREA */}
              <textarea
                ref={descriptionRef}
                name="description"
                placeholder="Description"
                value={eventForm.description}
                onChange={handleInputChange}
                rows="3"
                required
                style={{ gridColumn: "1 / -1" }}
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
                  "Update Event"
                ) : (
                  "Save Event"
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

      {/* Table Section Remains Same */}
      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Image</th>
              <th>Title</th>
              <th>Type</th>
              <th>Date & Time</th>
              <th>Location</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {events.length > 0 ? (
              events.map((event) => {
                const eventDate = new Date(event.date);
                const today = new Date();
                today.setHours(0, 0, 0, 0);
                const timeDiff = eventDate.getTime() - today.getTime();
                const daysDiff = Math.ceil(timeDiff / (1000 * 3600 * 24));
                let status;
                if (daysDiff < 0)
                  status = {
                    label: "Past",
                    class: "status-past",
                    icon: <FaTimesCircle />,
                  };
                else if (daysDiff === 0)
                  status = {
                    label: "Today",
                    class: "status-today",
                    icon: <FaCheckCircle />,
                  };
                else if (daysDiff <= 7)
                  status = {
                    label: "Upcoming",
                    class: "status-upcoming",
                    icon: <FaExclamationTriangle />,
                  };
                else
                  status = {
                    label: "Scheduled",
                    class: "status-scheduled",
                    icon: <FaCalendarAlt />,
                  };

                return (
                  <tr key={event._id}>
                    <td>
                      <img
                        src={event.image}
                        alt=""
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
                      <div
                        style={{
                          display: "flex",
                          flexDirection: "column",
                          fontSize: "0.9em",
                        }}
                      >
                        <span>
                          {eventDate.toLocaleDateString("en-GB", {
                            day: "2-digit",
                            month: "short",
                            year: "numeric",
                          })}
                        </span>
                        <span
                          style={{
                            color: "#666",
                            fontSize: "0.85em",
                            display: "flex",
                            alignItems: "center",
                            gap: "4px",
                          }}
                        >
                          <FaClock size={10} /> {event.time || "10:00 AM"}
                        </span>
                      </div>
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
                          >
                            <FaEdit />
                          </button>
                          <button
                            onClick={() =>
                              setDeleteModal({ show: true, id: event._id })
                            }
                            className="delete-btn compact-btn"
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
