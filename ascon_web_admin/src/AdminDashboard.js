import React, { useState, useEffect } from "react";
import axios from "axios";
import "./App.css";
import Toast from "./Toast";
import ConfirmModal from "./ConfirmModal";
// Import your logo
import logo from "./assets/logo.png";

function AdminDashboard() {
  const [activeTab, setActiveTab] = useState("users");
  const [pendingUsers, setPendingUsers] = useState([]);
  const [eventsList, setEventsList] = useState([]);
  const [toast, setToast] = useState(null);

  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });

  const [eventTitle, setEventTitle] = useState("");
  const [eventDesc, setEventDesc] = useState("");
  const [eventLoc, setEventLoc] = useState("");
  const [eventType, setEventType] = useState("News");

  const showToast = (msg, type = "success") => {
    setToast({ message: msg, type });
  };

  useEffect(() => {
    fetchPendingUsers();
    fetchEvents();
  }, []);

  const fetchPendingUsers = async () => {
    try {
      const res = await axios.get(
        "https://ascon.onrender.com/api/admin/pending"
      );
      setPendingUsers(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  const fetchEvents = async () => {
    try {
      const res = await axios.get("https://ascon.onrender.com/api/events");
      setEventsList(res.data);
    } catch (err) {
      console.error("Error fetching events. Ensure backend is deployed.");
    }
  };

  const approveUser = async (id, name) => {
    try {
      await axios.put(`https://ascon.onrender.com/api/admin/verify/${id}`);
      showToast(`${name} has been verified!`, "success");
      fetchPendingUsers();
    } catch (err) {
      showToast("Failed to verify user.", "error");
    }
  };

  const postEvent = async (e) => {
    e.preventDefault();
    try {
      await axios.post("https://ascon.onrender.com/api/events", {
        title: eventTitle,
        description: eventDesc,
        location: eventLoc,
        date: new Date(),
        type: eventType,
      });
      showToast(`Published: "${eventTitle}"`, "success");
      setEventTitle("");
      setEventDesc("");
      setEventLoc("");
      fetchEvents();
    } catch (err) {
      showToast("Failed to post event.", "error");
    }
  };

  const handleDeleteClick = (id) => {
    setDeleteModal({ show: true, id: id });
  };

  const confirmDelete = async () => {
    const id = deleteModal.id;
    setDeleteModal({ show: false, id: null });

    try {
      await axios.delete(`https://ascon.onrender.com/api/events/${id}`);
      showToast("Event deleted successfully.", "success");
      fetchEvents();
    } catch (err) {
      showToast("Failed to delete event.", "error");
    }
  };

  const renderAvatar = (base64String) => {
    if (!base64String) return <div className="avatar-placeholder">👤</div>;
    return (
      <img
        src={`data:image/png;base64,${base64String}`}
        alt="Avatar"
        className="avatar"
      />
    );
  };

  return (
    <div className="admin-container">
      {/* --- CENTERED HEADER SECTION --- */}
      <div className="header-centered">
        <img src={logo} alt="ASCON Logo" className="admin-logo-main" />

        {/* ✅ UPDATED COLOR: Deep Green */}
        <h1 className="admin-title" style={{ color: "#1B5E3A" }}>
          ASCON Admin Portal
        </h1>
        <p className="admin-subtitle">Super Admin Dashboard</p>

        <div className="tabs-centered">
          <button
            onClick={() => setActiveTab("users")}
            className={`approve-btn ${activeTab === "users" ? "" : "inactive"}`}
            // ✅ UPDATED BACKGROUND COLOR: Deep Green
            style={{
              backgroundColor: activeTab === "users" ? "#1B5E3A" : "#ccc",
            }}
          >
            Verify Alumni ({pendingUsers.length})
          </button>
          <button
            onClick={() => setActiveTab("events")}
            className={`approve-btn ${
              activeTab === "events" ? "" : "inactive"
            }`}
            // ✅ UPDATED BACKGROUND COLOR: Deep Green
            style={{
              backgroundColor: activeTab === "events" ? "#1B5E3A" : "#ccc",
            }}
          >
            Manage News ({eventsList.length})
          </button>
        </div>
      </div>

      {/* NOTIFICATIONS & MODALS */}
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}

      <ConfirmModal
        isOpen={deleteModal.show}
        title="Delete Event?"
        message="Are you sure you want to delete this event? This action cannot be undone."
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={confirmDelete}
      />

      {/* --- TAB 1: VERIFY USERS --- */}
      {activeTab === "users" && (
        <div>
          {pendingUsers.length === 0 ? (
            <div className="empty-state">
              <h3 style={{ color: "#1B5E3A" }}>All Caught Up! ✅</h3>
              <p>No new alumni waiting for verification.</p>
            </div>
          ) : (
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Photo</th>
                  <th>Full Name</th>
                  <th>Professional Info</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {pendingUsers.map((user) => (
                  <tr key={user._id}>
                    <td data-label="Photo">
                      {renderAvatar(user.profilePicture)}
                    </td>
                    <td data-label="Full Name">
                      <strong>{user.fullName}</strong>
                      <div style={{ fontSize: "12px", color: "#666" }}>
                        Class of {user.yearOfAttendance}
                      </div>
                    </td>
                    <td data-label="Professional Info">
                      <div>{user.jobTitle || "No Job Title"}</div>
                      <div style={{ fontSize: "12px", color: "#666" }}>
                        {user.organization}
                      </div>
                    </td>
                    <td data-label="Action">
                      <button
                        onClick={() => approveUser(user._id, user.fullName)}
                        className="approve-btn"
                      >
                        VERIFY
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* --- TAB 2: MANAGE EVENTS --- */}
      {activeTab === "events" && (
        <div>
          {/* POST EVENT FORM */}
          <div
            className="empty-state"
            style={{
              textAlign: "left",
              marginBottom: "30px",
              backgroundColor: "white",
              border: "1px solid #ddd",
            }}
          >
            {/* ✅ UPDATED HEADER COLOR */}
            <h2 style={{ color: "#1B5E3A", marginTop: 0 }}>
              📢 Post New Announcement
            </h2>
            <form onSubmit={postEvent}>
              <div style={{ marginBottom: "15px" }}>
                <label style={{ fontWeight: "bold" }}>Title</label>
                <input
                  style={{
                    width: "100%",
                    padding: "10px",
                    marginTop: "5px",
                    boxSizing: "border-box",
                  }}
                  value={eventTitle}
                  onChange={(e) => setEventTitle(e.target.value)}
                  required
                  placeholder="Event Title"
                />
              </div>
              <div
                style={{ display: "flex", gap: "10px", marginBottom: "15px" }}
              >
                <div style={{ flex: 1 }}>
                  <label style={{ fontWeight: "bold" }}>Location</label>
                  <input
                    style={{
                      width: "100%",
                      padding: "10px",
                      marginTop: "5px",
                      boxSizing: "border-box",
                    }}
                    value={eventLoc}
                    onChange={(e) => setEventLoc(e.target.value)}
                    required
                    placeholder="e.g. Auditorium"
                  />
                </div>
                <div style={{ flex: 1 }}>
                  <label style={{ fontWeight: "bold" }}>Type</label>
                  <select
                    style={{
                      width: "100%",
                      padding: "10px",
                      marginTop: "5px",
                      boxSizing: "border-box",
                    }}
                    value={eventType}
                    onChange={(e) => setEventType(e.target.value)}
                  >
                    <option>News</option>
                    <option>Reunion</option>
                    <option>Seminar</option>
                  </select>
                </div>
              </div>
              <div style={{ marginBottom: "15px" }}>
                <label style={{ fontWeight: "bold" }}>Description</label>
                <textarea
                  style={{
                    width: "100%",
                    padding: "10px",
                    marginTop: "5px",
                    height: "80px",
                    boxSizing: "border-box",
                  }}
                  value={eventDesc}
                  onChange={(e) => setEventDesc(e.target.value)}
                  required
                  placeholder="Details..."
                />
              </div>
              <button
                type="submit"
                className="approve-btn"
                style={{ width: "100%", padding: "12px" }}
              >
                PUBLISH POST
              </button>
            </form>
          </div>

          {/* EVENTS LIST */}
          {eventsList.length === 0 ? (
            <div className="empty-state">No events posted yet.</div>
          ) : (
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Type</th>
                  <th>Title & Location</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {eventsList.map((event) => (
                  <tr key={event._id}>
                    <td
                      data-label="Date"
                      style={{ fontSize: "13px", color: "#555" }}
                    >
                      {new Date(event.date).toLocaleDateString()}
                    </td>
                    <td data-label="Type">
                      <span
                        className="tag"
                        style={{
                          backgroundColor:
                            event.type === "Reunion" ? "#e6ffe6" : "#fff3cd",
                          color: event.type === "Reunion" ? "green" : "#856404",
                        }}
                      >
                        {event.type}
                      </span>
                    </td>
                    <td data-label="Title">
                      <div style={{ fontWeight: "bold" }}>{event.title}</div>
                      <div style={{ fontSize: "12px", color: "#666" }}>
                        📍 {event.location}
                      </div>
                    </td>
                    <td data-label="Action">
                      <button
                        className="delete-btn"
                        onClick={() => handleDeleteClick(event._id)}
                      >
                        DELETE
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}

export default AdminDashboard;
