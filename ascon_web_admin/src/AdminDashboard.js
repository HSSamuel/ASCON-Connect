import React, { useState, useEffect, useCallback, useMemo } from "react";
import axios from "axios";
import "./App.css";
import Toast from "./Toast";
import ConfirmModal from "./ConfirmModal";
import NavBar from "./components/NavBar";

// Import Sub-Components
import UsersTab from "./components/UsersTab";
import EventsTab from "./components/EventsTab";
import ProgrammesTab from "./components/ProgrammesTab";

// ✅ USE ENV VARIABLE
const BASE_URL = process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

function AdminDashboard({ token, onLogout }) {
  const [activeTab, setActiveTab] = useState("users");
  const [currentUser, setCurrentUser] = useState(null);

  // --- PAGINATION & SEARCH STATE ---
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [search, setSearch] = useState("");

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
  const userRole = canEdit ? "Super Admin" : "Viewer";

  // --- 2. API SETUP (WITH SMART ERROR HANDLING) ---
  const API = useMemo(() => {
    const instance = axios.create({
      baseURL: `${BASE_URL}/api`,
      headers: { "auth-token": token },
    });

    // ✅ INTERCEPTOR: Catch Session Expiry (401, 403 OR 400 "Invalid Token")
    instance.interceptors.response.use(
      (response) => response,
      (error) => {
        // Check for Auth Errors
        if (error.response) {
          const status = error.response.status;
          const msg = error.response.data?.message || "";

          // Backend sends 400 "Invalid Token" when expired
          if (
            status === 401 ||
            status === 403 ||
            (status === 400 && msg === "Invalid Token")
          ) {
            // alert("Session Expired. Please Login Again."); // Optional Alert
            onLogout(); // Force Logout
          }
        }
        return Promise.reject(error);
      }
    );
    return instance;
  }, [token, onLogout]);

  // --- FETCH DATA (With Search) ---
  const fetchData = useCallback(async () => {
    try {
      if (activeTab === "users") {
        const res = await API.get(
          `/admin/users?page=${page}&limit=20&search=${search}`
        );
        if (Array.isArray(res.data)) {
          setUsersList(res.data);
          setTotalPages(1);
        } else {
          setUsersList(res.data.users || []);
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
      // Don't toast on fetch errors to avoid spamming the user
    }
  }, [activeTab, API, page, search]);

  useEffect(() => {
    const delayDebounceFn = setTimeout(() => {
      fetchData();
    }, 500);
    return () => clearTimeout(delayDebounceFn);
  }, [fetchData, search]);

  // --- HELPERS (Switch Tab) ---
  const switchTab = (tab) => {
    setActiveTab(tab);
    setEditingId(null);
    setPage(1);
    setSearch("");
    setEventForm({
      title: "",
      description: "",
      location: "",
      type: "News",
      image: "",
    });
    setProgForm({ title: "", code: "" });
  };

  // --- ACTIONS ---
  const approveUser = async (id, name) => {
    try {
      await API.put(`/admin/users/${id}/verify`);
      showToast(`${name} has been verified!`, "success");
      fetchData();
    } catch (err) {
      // ✅ DISPLAY ACTUAL SERVER ERROR
      showToast(
        err.response?.data?.message || "Failed to verify user.",
        "error"
      );
    }
  };

  const toggleEditPermission = async (id) => {
    try {
      await API.put(`/admin/users/${id}/toggle-edit`);
      showToast("Permissions updated", "success");
      fetchData();
    } catch (err) {
      showToast(
        err.response?.data?.message || "Failed to update permissions",
        "error"
      );
    }
  };

  const toggleAdmin = async (id) => {
    try {
      await API.put(`/admin/users/${id}/toggle-admin`);
      showToast("Admin access updated", "success");
      fetchData();
    } catch (err) {
      showToast(
        err.response?.data?.message || "Failed to update admin status",
        "error"
      );
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
      // ✅ DISPLAY ACTUAL SERVER ERROR (e.g. "Invalid Token" or "Title missing")
      showToast(
        err.response?.data?.message || "Failed to save event.",
        "error"
      );
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
      showToast(
        err.response?.data?.message || "Failed to save programme.",
        "error"
      );
    }
  };
  const deleteProgrammeClick = (id) =>
    setDeleteModal({ show: true, id: id, type: "programme" });

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
      showToast(err.response?.data?.message || "Failed to delete.", "error");
    }
  };

  return (
    <div className="admin-container">
      {/* 2. NAVBAR */}
      <NavBar
        activeTab={activeTab}
        setActiveTab={switchTab}
        onLogout={onLogout}
        userRole={userRole}
      />

      {/* 3. SEARCH BAR (Floating below Navbar, Centered) */}
      {activeTab === "users" && (
        <div
          style={{
            marginTop: "20px",
            marginBottom: "20px",
            display: "flex",
            justifyContent: "center",
          }}
        >
          <div
            style={{
              position: "relative",
              maxWidth: "400px",
              width: "100%",
              margin: "0 20px",
            }}
          >
            <span
              style={{
                position: "absolute",
                left: "15px",
                top: "12px",
                fontSize: "16px",
              }}
            >
              🔍
            </span>
            <input
              type="text"
              placeholder="Search by Name, Email or ID..."
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
              style={{
                padding: "12px 12px 12px 45px",
                width: "100%",
                borderRadius: "30px",
                border: "1px solid #ddd",
                outline: "none",
                fontSize: "14px",
                boxShadow: "0 4px 6px rgba(0,0,0,0.05)",
              }}
            />
          </div>
        </div>
      )}

      {/* TOAST & MODAL */}
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
      <div
        className="content-padding"
        style={{
          padding: "0 20px",
          marginTop: activeTab === "users" ? "0px" : "30px",
        }}
      >
        {activeTab === "users" && (
          <UsersTab
            usersList={usersList}
            canEdit={canEdit}
            approveUser={approveUser}
            toggleAdmin={toggleAdmin}
            toggleEditPermission={toggleEditPermission}
            deleteUserClick={deleteUserClick}
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
    </div>
  );
}

export default AdminDashboard;
