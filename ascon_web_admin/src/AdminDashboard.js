import React, { useState, useEffect, useCallback, useMemo } from "react";
import axios from "axios";
import "./App.css";
import Toast from "./Toast";
import ConfirmModal from "./ConfirmModal";
import logo from "./assets/logo.png";

// Import Sub-Components
import UsersTab from "./components/UsersTab";
import EventsTab from "./components/EventsTab";
import ProgrammesTab from "./components/ProgrammesTab";

// ✅ USE ENV VARIABLE
const BASE_URL = process.env.REACT_APP_API_URL || "http://localhost:5000";

function AdminDashboard({ token, onLogout }) {
  const [activeTab, setActiveTab] = useState("users");
  const [currentUser, setCurrentUser] = useState(null);

  // --- PAGINATION STATE ---
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);

  // --- DATA LISTS ---
  const [usersList, setUsersList] = useState([]);
  const [eventsList, setEventsList] = useState([]);
  const [programmesList, setProgrammesList] = useState([]);

  // --- UI STATE ---
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({
    show: false,
    id: null,
    type: null,
  });

  // --- FORMS STATE ---
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

  // --- 1. AUTH CHECK ---
  useEffect(() => {
    if (token) {
      try {
        const base64Url = token.split(".")[1];
        const base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
        const jsonPayload = decodeURIComponent(
          window
            .atob(base64)
            .split("")
            .map((c) => "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2))
            .join("")
        );
        setCurrentUser(JSON.parse(jsonPayload));
      } catch (e) {
        console.error("Error decoding token", e);
      }
    }
  }, [token]);

  const canEdit = currentUser?.canEdit || false;

  // --- 2. API SETUP ---
  const API = useMemo(() => {
    const instance = axios.create({
      baseURL: `${BASE_URL}/api`,
      headers: { "auth-token": token },
    });
    instance.interceptors.response.use(
      (response) => response,
      (error) => {
        if (
          error.response &&
          (error.response.status === 401 || error.response.status === 403)
        ) {
          onLogout();
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
        const res = await API.get(`/admin/users?page=${page}&limit=20`);

        // ✅ SAFETY FIX: Check what format the backend sent
        if (Array.isArray(res.data)) {
          // OLD FORMAT (Just an array)
          setUsersList(res.data);
          setTotalPages(1);
        } else {
          // NEW FORMAT (Object with pagination)
          setUsersList(res.data.users || []); // Default to [] if missing
          setTotalPages(res.data.pages || 1);
        }
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
  }, [activeTab, API, page]); // Re-run when page changes

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // --- TABS & ACTIONS ---
  const switchTab = (tab) => {
    setActiveTab(tab);
    setEditingId(null);
    setPage(1); // Reset page when switching tabs
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

  const toggleAdmin = async (id) => {
    try {
      await API.put(`/admin/users/${id}/toggle-admin`);
      showToast("Admin access updated", "success");
      fetchData();
    } catch (err) {
      showToast("Failed to update admin status", "error");
    }
  };

  const deleteUserClick = (id) =>
    setDeleteModal({ show: true, id: id, type: "user" });

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
        showToast("Event updated", "success");
        setEditingId(null);
      } else {
        await API.post("/admin/events", { ...eventForm, date: new Date() });
        showToast("Event published", "success");
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
  const deleteEventClick = (id) =>
    setDeleteModal({ show: true, id: id, type: "event" });

  // --- PROGRAMME ACTIONS ---
  const startEditProgramme = (prog) => {
    setEditingId(prog._id);
    setProgForm({ title: prog.title, code: prog.code || "" });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };
  const cancelEditProgramme = () => {
    setEditingId(null);
    setProgForm({ title: "", code: "" });
  };
  const handleProgrammeSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        await API.put(`/admin/programmes/${editingId}`, progForm);
        showToast("Programme updated", "success");
        setEditingId(null);
      } else {
        await API.post("/admin/programmes", progForm);
        showToast("Programme added", "success");
      }
      setProgForm({ title: "", code: "" });
      fetchData();
    } catch (err) {
      showToast(err.response?.data?.message || "Failed.", "error");
    }
  };
  const deleteProgrammeClick = (id) =>
    setDeleteModal({ show: true, id: id, type: "programme" });

  // --- GLOBAL DELETE ---
  const confirmDelete = async () => {
    const { id, type } = deleteModal;
    setDeleteModal({ show: false, id: null, type: null });
    try {
      if (type === "event") await API.delete(`/admin/events/${id}`);
      if (type === "programme") await API.delete(`/admin/programmes/${id}`);
      if (type === "user") await API.delete(`/admin/users/${id}`);
      showToast("Item deleted.", "success");
      fetchData();
    } catch (err) {
      showToast("Failed to delete.", "error");
    }
  };

  return (
    <div className="admin-container">
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
          {["users", "events", "programmes"].map((tab) => (
            <button
              key={tab}
              onClick={() => switchTab(tab)}
              className={`approve-btn ${activeTab === tab ? "" : "inactive"}`}
              style={{
                backgroundColor: activeTab === tab ? "#1B5E3A" : "#ccc",
                textTransform: "capitalize",
              }}
            >
              {tab}
            </button>
          ))}
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

      {/* RENDER ACTIVE TAB */}
      {activeTab === "users" && (
        <UsersTab
          usersList={usersList}
          canEdit={canEdit}
          approveUser={approveUser}
          toggleAdmin={toggleAdmin}
          toggleEditPermission={toggleEditPermission}
          deleteUserClick={deleteUserClick}
          // ✅ Pass Pagination Props
          page={page}
          setPage={setPage}
          totalPages={totalPages}
        />
      )}

      {activeTab === "events" && (
        <EventsTab
          eventsList={eventsList}
          canEdit={canEdit}
          editingId={editingId}
          eventForm={eventForm}
          setEventForm={setEventForm}
          handleEventSubmit={handleEventSubmit}
          cancelEditEvent={cancelEditEvent}
          startEditEvent={startEditEvent}
          deleteEventClick={deleteEventClick}
        />
      )}

      {activeTab === "programmes" && (
        <ProgrammesTab
          programmesList={programmesList}
          canEdit={canEdit}
          editingId={editingId}
          progForm={progForm}
          setProgForm={setProgForm}
          handleProgrammeSubmit={handleProgrammeSubmit}
          cancelEditProgramme={cancelEditProgramme}
          startEditProgramme={startEditProgramme}
          deleteProgrammeClick={deleteProgrammeClick}
        />
      )}
    </div>
  );
}

export default AdminDashboard;
