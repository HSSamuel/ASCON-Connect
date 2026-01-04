import React, { useState, useEffect, useCallback, useMemo } from "react";
import axios from "axios";
import "./App.css";
import Toast from "./Toast";
import ConfirmModal from "./ConfirmModal";
import logo from "./assets/logo.png";

// ✅ CONFIG: Change this to your live URL when deploying
const BASE_URL =
  window.location.hostname === "localhost"
    ? "http://localhost:5000"
    : "https://ascon.onrender.com";

function AdminDashboard({ token, onLogout }) {
  const [activeTab, setActiveTab] = useState("users"); // users | events | programmes

  // --- STATE: PERMISSIONS ---
  const [currentUser, setCurrentUser] = useState(null);

  // --- STATE: DATA LISTS ---
  const [usersList, setUsersList] = useState([]);
  const [eventsList, setEventsList] = useState([]);
  const [programmesList, setProgrammesList] = useState([]);

  // --- STATE: UI ---
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({
    show: false,
    id: null,
    type: null,
  });

  // --- STATE: FORMS ---
  const [editingId, setEditingId] = useState(null);
  const [eventForm, setEventForm] = useState({
    title: "",
    description: "",
    location: "",
    type: "News",
    image: "",
  });
  const [progForm, setProgForm] = useState({ title: "", code: "" });

  const showToast = (msg, type = "success") => {
    setToast({ message: msg, type });
  };

  // --- 1. DECODE TOKEN ON LOAD (Check Permissions) ---
  useEffect(() => {
    if (token) {
      try {
        const base64Url = token.split(".")[1];
        const base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
        const jsonPayload = decodeURIComponent(
          window
            .atob(base64)
            .split("")
            .map(function (c) {
              return "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2);
            })
            .join("")
        );
        setCurrentUser(JSON.parse(jsonPayload));
      } catch (e) {
        console.error("Error decoding token", e);
      }
    }
  }, [token]);

  // Helper variable
  const canEdit = currentUser?.canEdit || false;

  // --- API CONFIG (With Auto-Logout Interceptor) ---
  const API = useMemo(() => {
    const instance = axios.create({
      baseURL: `${BASE_URL}/api`,
      headers: { "auth-token": token },
    });

    // ✅ NEW: Intercept 401/403 errors -> Force Logout
    instance.interceptors.response.use(
      (response) => response,
      (error) => {
        if (
          error.response &&
          (error.response.status === 401 || error.response.status === 403)
        ) {
          onLogout(); // Kick user out
        }
        return Promise.reject(error);
      }
    );

    return instance;
  }, [token, onLogout]);

  // --- FETCH DATA ---
  const fetchData = useCallback(async () => {
    try {
      if (activeTab === "users") {
        const res = await API.get("/admin/users");
        setUsersList(res.data);
      } else if (activeTab === "events") {
        const res = await API.get("/events");
        setEventsList(res.data.events || res.data);
      } else if (activeTab === "programmes") {
        const res = await API.get("/admin/programmes");
        setProgrammesList(res.data);
      }
    } catch (err) {
      console.error(err);
    }
  }, [activeTab, API]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // --- HELPER: SWITCH TABS & CLEAR FORMS ---
  const switchTab = (tab) => {
    setActiveTab(tab);
    setEditingId(null);
    setEventForm({
      title: "",
      description: "",
      location: "",
      type: "News",
      image: "",
    });
    setProgForm({ title: "", code: "" });
  };

  // --- USER ACTIONS ---
  const approveUser = async (id, name) => {
    try {
      await API.put(`/admin/users/${id}/verify`);
      showToast(`${name} has been verified!`, "success");
      fetchData();
    } catch (err) {
      showToast("Failed to verify user.", "error");
    }
  };

  const toggleEditPermission = async (id) => {
    try {
      await API.put(`/admin/users/${id}/toggle-edit`);
      showToast("Permissions updated", "success");
      fetchData();
    } catch (err) {
      showToast("Failed to update permissions", "error");
    }
  };

  // ✅ NEW: Toggle Admin Status
  const toggleAdmin = async (id) => {
    try {
      await API.put(`/admin/users/${id}/toggle-admin`);
      showToast("Admin access updated", "success");
      fetchData();
    } catch (err) {
      showToast("Failed to update admin status", "error");
    }
  };

  const deleteUserClick = (id) => {
    setDeleteModal({ show: true, id: id, type: "user" });
  };

  // --- EVENT ACTIONS ---
  const startEditEvent = (event) => {
    setEditingId(event._id);
    setEventForm({
      title: event.title,
      description: event.description,
      location: event.location,
      type: event.type,
      image: event.image || "",
    });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const cancelEditEvent = () => {
    setEditingId(null);
    setEventForm({
      title: "",
      description: "",
      location: "",
      type: "News",
      image: "",
    });
  };

  const handleEventSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        await API.put(`/admin/events/${editingId}`, eventForm);
        showToast(`Updated: "${eventForm.title}"`, "success");
        setEditingId(null);
      } else {
        await API.post("/admin/events", {
          ...eventForm,
          date: new Date(),
        });
        showToast(`Published: "${eventForm.title}"`, "success");
      }
      setEventForm({
        title: "",
        description: "",
        location: "",
        type: "News",
        image: "",
      });
      fetchData();
    } catch (err) {
      showToast("Failed to save event.", "error");
    }
  };

  const deleteEventClick = (id) => {
    setDeleteModal({ show: true, id: id, type: "event" });
  };

  // --- PROGRAMME ACTIONS (UPDATED) ---

  // 1. Start Editing
  const startEditProgramme = (prog) => {
    setEditingId(prog._id);
    setProgForm({
      title: prog.title,
      code: prog.code || "",
    });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  // 2. Cancel Editing
  const cancelEditProgramme = () => {
    setEditingId(null);
    setProgForm({ title: "", code: "" });
  };

  // 3. Handle Submit (Add OR Update)
  const handleProgrammeSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        // UPDATE LOGIC
        await API.put(`/admin/programmes/${editingId}`, progForm);
        showToast("Programme updated successfully!", "success");
        setEditingId(null);
      } else {
        // ADD LOGIC
        await API.post("/admin/programmes", progForm);
        showToast("Programme added successfully!", "success");
      }

      // Reset Form & Refresh
      setProgForm({ title: "", code: "" });
      fetchData();
    } catch (err) {
      showToast(
        err.response?.data?.message || "Failed to save programme.",
        "error"
      );
    }
  };

  const deleteProgrammeClick = (id) => {
    setDeleteModal({ show: true, id: id, type: "programme" });
  };

  // --- UNIVERSAL DELETE CONFIRM ---
  const confirmDelete = async () => {
    const { id, type } = deleteModal;
    setDeleteModal({ show: false, id: null, type: null });

    try {
      if (type === "event") await API.delete(`/admin/events/${id}`);
      if (type === "programme") await API.delete(`/admin/programmes/${id}`);
      if (type === "user") await API.delete(`/admin/users/${id}`);

      showToast(
        `${type.charAt(0).toUpperCase() + type.slice(1)} deleted.`,
        "success"
      );
      fetchData();
    } catch (err) {
      showToast("Failed to delete item.", "error");
    }
  };

  const renderAvatar = (imagePath) => {
    if (!imagePath) return <div className="avatar-placeholder">👤</div>;
    if (imagePath.startsWith("http"))
      return <img src={imagePath} alt="Avatar" className="avatar" />;
    return (
      <img
        src={`data:image/png;base64,${imagePath}`}
        alt="Avatar"
        className="avatar"
      />
    );
  };

  return (
    <div className="admin-container">
      {/* HEADER */}
      <div className="header-centered">
        <div style={{ position: "absolute", right: 20, top: 20 }}>
          <button
            onClick={onLogout}
            className="delete-btn"
            style={{ fontSize: "12px" }}
          >
            LOGOUT
          </button>
        </div>

        <img src={logo} alt="ASCON Logo" className="admin-logo-main" />
        <h1 className="admin-title" style={{ color: "#1B5E3A" }}>
          ASCON Admin Portal
        </h1>
        <p className="admin-subtitle">
          {canEdit ? "Super Admin Dashboard" : "View-Only Dashboard"}
        </p>

        <div className="tabs-centered">
          <button
            onClick={() => switchTab("users")}
            className={`approve-btn ${activeTab === "users" ? "" : "inactive"}`}
            style={{
              backgroundColor: activeTab === "users" ? "#1B5E3A" : "#ccc",
            }}
          >
            Users
          </button>
          <button
            onClick={() => switchTab("events")}
            className={`approve-btn ${
              activeTab === "events" ? "" : "inactive"
            }`}
            style={{
              backgroundColor: activeTab === "events" ? "#1B5E3A" : "#ccc",
            }}
          >
            Events
          </button>
          <button
            onClick={() => switchTab("programmes")}
            className={`approve-btn ${
              activeTab === "programmes" ? "" : "inactive"
            }`}
            style={{
              backgroundColor: activeTab === "programmes" ? "#1B5E3A" : "#ccc",
            }}
          >
            Programmes
          </button>
        </div>
      </div>

      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}

      <ConfirmModal
        isOpen={deleteModal.show}
        title="Confirm Deletion"
        message="Are you sure? This action cannot be undone."
        onClose={() => setDeleteModal({ show: false, id: null, type: null })}
        onConfirm={confirmDelete}
      />

      {/* TAB 1: USERS */}
      {activeTab === "users" && (
        <div>
          {/* ✅ WRAPPED FOR SCROLLABLE TABLE */}
          <div className="table-responsive">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Photo</th>
                  <th>Full Name</th>
                  <th>Status</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {usersList.map((user) => (
                  <tr key={user._id}>
                    <td data-label="Photo">
                      {renderAvatar(user.profilePicture)}
                    </td>
                    <td data-label="Full Name">
                      <strong>{user.fullName}</strong>
                      <div style={{ fontSize: "12px", color: "#666" }}>
                        {user.email}
                      </div>
                      {/* Visual indicators */}
                      <div style={{ marginTop: "5px" }}>
                        {user.isAdmin && (
                          <span
                            className="tag"
                            style={{
                              backgroundColor: "#007bff",
                              color: "white",
                              fontSize: "10px",
                              marginRight: "5px",
                            }}
                          >
                            ADMIN
                          </span>
                        )}
                        {user.canEdit && (
                          <span
                            className="tag"
                            style={{
                              backgroundColor: "#d4af37",
                              color: "white",
                              fontSize: "10px",
                            }}
                          >
                            EDITOR
                          </span>
                        )}
                      </div>
                    </td>
                    <td data-label="Status">
                      <span
                        className={`status-badge ${
                          user.isVerified ? "verified" : "pending"
                        }`}
                      >
                        {user.isVerified ? "Verified" : "Pending"}
                      </span>
                    </td>
                    <td data-label="Action">
                      {/* ✅ SIDE-BY-SIDE BUTTONS LAYOUT */}
                      {canEdit ? (
                        <div className="action-buttons-container">
                          {!user.isVerified && (
                            <button
                              onClick={() =>
                                approveUser(user._id, user.fullName)
                              }
                              className="approve-btn compact-btn"
                              title="Verify User"
                            >
                              VERIFY
                            </button>
                          )}

                          {/* ✅ TOGGLE ADMIN BUTTON */}
                          <button
                            onClick={() => toggleAdmin(user._id)}
                            className="approve-btn compact-btn"
                            style={{
                              backgroundColor: user.isAdmin
                                ? "#444"
                                : "#007bff",
                            }}
                            title={user.isAdmin ? "Revoke Admin" : "Make Admin"}
                          >
                            {user.isAdmin ? "REVOKE ADMIN" : "MAKE ADMIN"}
                          </button>

                          {/* Grant/Revoke Edit Rights (Only if Admin) */}
                          {user.isAdmin && (
                            <button
                              onClick={() => toggleEditPermission(user._id)}
                              className="approve-btn compact-btn"
                              style={{
                                backgroundColor: user.canEdit
                                  ? "#555"
                                  : "purple",
                              }}
                              title={
                                user.canEdit ? "Revoke Edit" : "Grant Edit"
                              }
                            >
                              {user.canEdit ? "REVOKE EDIT" : "GRANT EDIT"}
                            </button>
                          )}

                          <button
                            onClick={() => deleteUserClick(user._id)}
                            className="delete-btn compact-btn"
                            title="Delete User"
                          >
                            DELETE
                          </button>
                        </div>
                      ) : (
                        <span style={{ color: "#999", fontSize: "12px" }}>
                          View Only
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 2: EVENTS */}
      {activeTab === "events" && (
        <div>
          {canEdit ? (
            <div
              className="empty-state"
              style={{
                textAlign: "left",
                marginBottom: "30px",
                backgroundColor: "white",
                border: "1px solid #ddd",
              }}
            >
              <h2
                style={{
                  color: editingId ? "#d4af37" : "#1B5E3A",
                  marginTop: 0,
                }}
              >
                {editingId ? "✏️ Edit Announcement" : "📢 Post Announcement"}
              </h2>

              <form onSubmit={handleEventSubmit}>
                <div style={{ display: "flex", gap: "10px" }}>
                  <input
                    style={{ flex: 2, padding: "10px", marginBottom: "10px" }}
                    placeholder="Event Title"
                    value={eventForm.title}
                    onChange={(e) =>
                      setEventForm({ ...eventForm, title: e.target.value })
                    }
                    required
                  />
                  <select
                    style={{ flex: 1, padding: "10px", marginBottom: "10px" }}
                    value={eventForm.type}
                    onChange={(e) =>
                      setEventForm({ ...eventForm, type: e.target.value })
                    }
                  >
                    <option>News</option>
                    <option>Reunion</option>
                    <option>Seminar</option>
                    <option>Webinar</option>
                  </select>
                </div>
                <input
                  style={{
                    width: "100%",
                    padding: "10px",
                    marginBottom: "10px",
                    boxSizing: "border-box",
                  }}
                  placeholder="Image URL (e.g. https://imgur.com/...)"
                  value={eventForm.image}
                  onChange={(e) =>
                    setEventForm({ ...eventForm, image: e.target.value })
                  }
                />
                <input
                  style={{
                    width: "100%",
                    padding: "10px",
                    marginBottom: "10px",
                    boxSizing: "border-box",
                  }}
                  placeholder="Location"
                  value={eventForm.location}
                  onChange={(e) =>
                    setEventForm({ ...eventForm, location: e.target.value })
                  }
                  required
                />
                <textarea
                  style={{
                    width: "100%",
                    padding: "10px",
                    marginBottom: "10px",
                    height: "80px",
                    boxSizing: "border-box",
                  }}
                  placeholder="Details..."
                  value={eventForm.description}
                  onChange={(e) =>
                    setEventForm({ ...eventForm, description: e.target.value })
                  }
                  required
                />

                <div style={{ display: "flex", gap: "10px" }}>
                  <button
                    type="submit"
                    className="approve-btn"
                    style={{
                      flex: 1,
                      padding: "12px",
                      backgroundColor: editingId ? "#d4af37" : "#1B5E3A",
                    }}
                  >
                    {editingId ? "UPDATE EVENT" : "PUBLISH POST"}
                  </button>
                  {editingId && (
                    <button
                      type="button"
                      onClick={cancelEditEvent}
                      className="delete-btn"
                      style={{ flex: 0.3, backgroundColor: "#666" }}
                    >
                      CANCEL
                    </button>
                  )}
                </div>
              </form>
            </div>
          ) : (
            <div className="empty-state">🔒 View-Only Mode enabled.</div>
          )}

          {/* ✅ WRAPPED FOR SCROLLABLE TABLE */}
          <div className="table-responsive">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Image</th>
                  <th>Date</th>
                  <th>Title</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {eventsList.map((event) => (
                  <tr key={event._id}>
                    <td data-label="Image">
                      <img
                        src={event.image || "https://via.placeholder.com/50"}
                        alt="banner"
                        style={{
                          width: "50px",
                          height: "30px",
                          objectFit: "cover",
                          borderRadius: "4px",
                        }}
                      />
                    </td>
                    <td
                      data-label="Date"
                      style={{ fontSize: "13px", color: "#555" }}
                    >
                      {new Date(event.date).toLocaleDateString()}
                    </td>
                    <td data-label="Title">
                      <div style={{ fontWeight: "bold" }}>{event.title}</div>
                      <span className="tag">{event.type}</span>
                    </td>
                    <td data-label="Action">
                      {canEdit ? (
                        <div className="action-buttons-container">
                          <button
                            onClick={() => startEditEvent(event)}
                            className="approve-btn compact-btn"
                            style={{ backgroundColor: "#3498db" }}
                          >
                            EDIT
                          </button>
                          <button
                            className="delete-btn compact-btn"
                            onClick={() => deleteEventClick(event._id)}
                          >
                            DELETE
                          </button>
                        </div>
                      ) : (
                        <span style={{ color: "#ccc" }}>🔒</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 3: PROGRAMMES (✅ UPDATED FOR EDITING) */}
      {activeTab === "programmes" && (
        <div>
          {canEdit ? (
            <div
              className="empty-state"
              style={{
                textAlign: "left",
                marginBottom: "30px",
                backgroundColor: "white",
                border: "1px solid #ddd",
              }}
            >
              <h2
                style={{
                  color: editingId ? "#d4af37" : "#1B5E3A",
                  marginTop: 0,
                }}
              >
                {editingId ? "✏️ Edit Programme" : "🎓 Add New Programme"}
              </h2>
              <form
                onSubmit={handleProgrammeSubmit}
                style={{ display: "flex", gap: "10px" }}
              >
                <input
                  style={{ flex: 3, padding: "10px" }}
                  placeholder="Programme Title"
                  value={progForm.title}
                  onChange={(e) =>
                    setProgForm({ ...progForm, title: e.target.value })
                  }
                  required
                />
                <input
                  style={{ flex: 1, padding: "10px" }}
                  placeholder="Code"
                  value={progForm.code}
                  onChange={(e) =>
                    setProgForm({ ...progForm, code: e.target.value })
                  }
                />
                <button
                  type="submit"
                  className="approve-btn"
                  style={{
                    backgroundColor: editingId ? "#d4af37" : "#1B5E3A",
                  }}
                >
                  {editingId ? "UPDATE" : "ADD"}
                </button>

                {/* ✅ CANCEL BUTTON FOR PROGRAMMES */}
                {editingId && (
                  <button
                    type="button"
                    onClick={cancelEditProgramme}
                    className="delete-btn"
                    style={{ backgroundColor: "#666" }}
                  >
                    CANCEL
                  </button>
                )}
              </form>
            </div>
          ) : (
            <div className="empty-state">🔒 View-Only Mode enabled.</div>
          )}

          {/* ✅ WRAPPED FOR SCROLLABLE TABLE */}
          <div className="table-responsive">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Code</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {programmesList.map((prog) => (
                  <tr key={prog._id}>
                    <td data-label="Title">
                      <strong>{prog.title}</strong>
                    </td>
                    <td data-label="Code">{prog.code || "-"}</td>
                    <td data-label="Action">
                      {canEdit ? (
                        <div className="action-buttons-container">
                          {/* ✅ EDIT BUTTON FOR PROGRAMMES */}
                          <button
                            onClick={() => startEditProgramme(prog)}
                            className="approve-btn compact-btn"
                            style={{ backgroundColor: "#3498db" }}
                          >
                            EDIT
                          </button>

                          <button
                            className="delete-btn compact-btn"
                            onClick={() => deleteProgrammeClick(prog._id)}
                          >
                            REMOVE
                          </button>
                        </div>
                      ) : (
                        <span style={{ color: "#ccc" }}>🔒</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

export default AdminDashboard;
