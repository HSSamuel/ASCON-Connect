import React, { useState } from "react";
import axios from "axios";
import EventsTab from "../components/EventsTab";
import ConfirmModal from "../ConfirmModal";
import Toast from "../Toast";
import { usePaginatedFetch } from "../hooks/usePaginatedFetch";

const BASE_URL = process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

function EventsManager({ token, canEdit }) {
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });

  const [editingId, setEditingId] = useState(null);

  // ✅ UPDATE 1: Add 'location' to initial state
  const [eventForm, setEventForm] = useState({
    title: "",
    description: "",
    type: "News",
    image: "",
    location: "",
  });

  const events = usePaginatedFetch(`${BASE_URL}/api/events`, token);

  const showToast = (message, type = "success") => setToast({ message, type });

  const resetForm = () => {
    setEditingId(null);
    // ✅ UPDATE 2: Reset location too
    setEventForm({
      title: "",
      description: "",
      type: "News",
      image: "",
      location: "",
    });
  };

  // 🧹 HELPER: Sanitizes data to remove system fields
  const sanitizePayload = (data) => {
    // ✅ FIX: Do NOT remove 'location' anymore!
    // We only remove system fields (_id, createdAt, etc.)
    const { _id, id, createdAt, updatedAt, __v, ...cleanData } = data;

    // Ensure location is never undefined (send empty string if missing)
    if (!cleanData.location) cleanData.location = "";

    return cleanData;
  };

  const handleEventSubmit = async (e) => {
    e.preventDefault();
    if (eventForm.title.length < 5)
      return showToast("Title must be at least 5 chars", "error");

    try {
      const cleanData = sanitizePayload(eventForm);

      if (editingId) {
        await axios.put(
          `${BASE_URL}/api/admin/events/${editingId}`, // Ensure this route exists in backend/routes/admin.js or events.js
          cleanData,
          {
            headers: { "auth-token": token },
          }
        );
        showToast("Event updated successfully");
      } else {
        await axios.post(
          `${BASE_URL}/api/events`, // Changed from /api/admin/events to match your backend route
          { ...cleanData, date: new Date() },
          {
            headers: { "auth-token": token },
          }
        );
        showToast("Event created successfully");
      }
      resetForm();
      events.refresh();
    } catch (err) {
      console.error(err);
      showToast(err.response?.data?.message || "Error saving event", "error");
    }
  };

  const handleDelete = async () => {
    try {
      await axios.delete(`${BASE_URL}/api/events/${deleteModal.id}`, {
        // Updated route to match backend
        headers: { "auth-token": token },
      });
      showToast("Event deleted");
      events.refresh();
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
        title="Delete Event"
        message="Are you sure? This cannot be undone."
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={handleDelete}
      />

      <EventsTab
        eventsList={events.data}
        canEdit={canEdit}
        editingId={editingId}
        eventForm={eventForm}
        setEventForm={setEventForm}
        handleEventSubmit={handleEventSubmit}
        startEditEvent={(evt) => {
          setEditingId(evt._id);
          // ✅ UPDATE 3: Ensure location is loaded when editing
          setEventForm({
            ...evt,
            image: evt.image || "",
            location: evt.location || "",
          });
          window.scrollTo(0, 0);
        }}
        cancelEditEvent={resetForm}
        deleteEventClick={(id) => setDeleteModal({ show: true, id })}
      />
    </div>
  );
}

export default EventsManager;
