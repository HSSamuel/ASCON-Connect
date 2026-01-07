import React, { useState, useMemo, useEffect } from "react"; // ✅ Added useEffect
import axios from "axios";
import "./App.css";
import Toast from "./Toast";
import ConfirmModal from "./ConfirmModal";
import NavBar from "./components/NavBar";
import StatCard from "./components/StatCard";

// Sub-Components
import UsersTab from "./components/UsersTab";
import EventsTab from "./components/EventsTab";
import ProgrammesTab from "./components/ProgrammesTab";
import RegistrationsTab from "./components/RegistrationsTab";

// Custom Hooks
import { useAuth } from "./hooks/useAuth";
import { usePaginatedFetch } from "./hooks/usePaginatedFetch";
import { useStats } from "./hooks/useStats";

const BASE_URL = process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

function AdminDashboard({ token, onLogout }) {
  // --- 1. STATE & HOOKS ---
  const [activeTab, setActiveTab] = useState("users");
  const [refreshCount, setRefreshCount] = useState(0); // Trigger to reload data
  const [toast, setToast] = useState(null);

  // ✅ THEME STATE (Persistence via localStorage)
  const [theme, setTheme] = useState(localStorage.getItem("theme") || "light");

  // UI State for Modals/Forms
  const [deleteModal, setDeleteModal] = useState({
    show: false,
    id: null,
    type: null,
  });
  const [editingId, setEditingId] = useState(null);
  const [eventForm, setEventForm] = useState({
    title: "",
    description: "",
    location: "",
    type: "News",
    image: "",
  });
  const [progForm, setProgForm] = useState({
    title: "",
    code: "",
    description: "",
    duration: "",
    fee: "",
    image: "",
  });

  // ✅ APPLY THEME TO BODY ELEMENT
  useEffect(() => {
    document.body.setAttribute("data-theme", theme);
  }, [theme]);

  // ✅ THEME TOGGLE HANDLER
  const toggleTheme = () => {
    const newTheme = theme === "light" ? "dark" : "light";
    setTheme(newTheme);
    localStorage.setItem("theme", newTheme);
  };

  // ✅ AUTH HOOK
  const { canEdit, userRole } = useAuth(token, onLogout);

  // ✅ DATA HOOKS
  const users = usePaginatedFetch(
    `${BASE_URL}/api/admin/users`,
    token,
    refreshCount
  );
  const events = usePaginatedFetch(
    `${BASE_URL}/api/events`,
    token,
    refreshCount
  );
  const programmes = usePaginatedFetch(
    `${BASE_URL}/api/admin/programmes`,
    token,
    refreshCount
  );
  const progRegs = usePaginatedFetch(
    `${BASE_URL}/api/programme-interest`,
    token,
    refreshCount
  );
  const eventRegs = usePaginatedFetch(
    `${BASE_URL}/api/event-registration`,
    token,
    refreshCount
  );

  // ✅ STATS HOOK
  const stats = useStats(BASE_URL, token, refreshCount);

  // --- 2. API INSTANCE ---
  const API = useMemo(() => {
    const instance = axios.create({
      baseURL: `${BASE_URL}/api`,
      headers: { "auth-token": token },
    });
    instance.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response && [401, 403].includes(error.response.status)) {
          onLogout();
        }
        return Promise.reject(error);
      }
    );
    return instance;
  }, [token, onLogout]);

  // --- 3. HELPERS ---
  const showToast = (msg, type = "success") => setToast({ message: msg, type });
  const triggerRefresh = () => setRefreshCount((prev) => prev + 1);

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

  // --- 4. ACTIONS (Users) ---
  const approveUser = async (id, name) => {
    try {
      await API.put(`/admin/users/${id}/verify`);
      showToast(`${name} verified!`);
      users.refresh();
      triggerRefresh();
    } catch (err) {
      showToast(err.response?.data?.message || "Failed.", "error");
    }
  };

  const toggleAdmin = async (id) => {
    try {
      await API.put(`/admin/users/${id}/toggle-admin`);
      showToast("Admin status updated");
      users.refresh();
    } catch (err) {
      showToast("Failed to update.", "error");
    }
  };

  const toggleEditPermission = async (id) => {
    try {
      await API.put(`/admin/users/${id}/toggle-edit`);
      showToast("Permissions updated");
      users.refresh();
    } catch (err) {
      showToast("Failed to update.", "error");
    }
  };

  const deleteUserClick = (id) =>
    setDeleteModal({ show: true, id, type: "user" });

  // --- 5. ACTIONS (Events) ---
  const handleEventSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        await API.put(`/admin/events/${editingId}`, eventForm);
        showToast("Event updated");
      } else {
        await API.post("/admin/events", { ...eventForm, date: new Date() });
        showToast("Event published");
      }
      setEditingId(null);
      setEventForm({
        title: "",
        description: "",
        location: "",
        type: "News",
        image: "",
      });
      events.refresh();
      triggerRefresh();
    } catch (err) {
      showToast(err.response?.data?.message || "Error saving event", "error");
    }
  };

  const startEditEvent = (evt) => {
    setEditingId(evt._id);
    setEventForm({ ...evt, image: evt.image || "" });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const deleteEventClick = (id) =>
    setDeleteModal({ show: true, id, type: "event" });

  // --- 6. ACTIONS (Programmes) ---
  const handleProgrammeSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        await API.put(`/admin/programmes/${editingId}`, progForm);
        showToast("Programme updated");
      } else {
        await API.post("/admin/programmes", progForm);
        showToast("Programme added");
      }
      setEditingId(null);
      setProgForm({
        title: "",
        code: "",
        description: "",
        duration: "",
        fee: "",
        image: "",
      });
      programmes.refresh();
      triggerRefresh();
    } catch (err) {
      showToast(
        err.response?.data?.message || "Error saving programme",
        "error"
      );
    }
  };

  const startEditProgramme = (prog) => {
    setEditingId(prog._id);
    setProgForm({ ...prog, image: prog.image || "" });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const deleteProgrammeClick = (id) =>
    setDeleteModal({ show: true, id, type: "programme" });

  // --- 7. ACTIONS (Registrations) ---
  const handleDeleteRegistration = (id, type) => {
    const deleteType = type === "programmes" ? "reg_prog" : "reg_event";
    setDeleteModal({ show: true, id: id, type: deleteType });
  };

  // --- 8. SHARED DELETE CONFIRMATION ---
  const confirmDelete = async () => {
    const { id, type } = deleteModal;
    setDeleteModal({ show: false, id: null, type: null });
    try {
      if (type === "user") await API.delete(`/admin/users/${id}`);
      if (type === "event") await API.delete(`/admin/events/${id}`);
      if (type === "programme") await API.delete(`/admin/programmes/${id}`);
      if (type === "reg_prog") await API.delete(`/programme-interest/${id}`);
      if (type === "reg_event") await API.delete(`/event-registration/${id}`);

      showToast("Deleted successfully");
      triggerRefresh();

      if (type && type.startsWith("reg_")) {
        progRegs.refresh();
        eventRegs.refresh();
      }
    } catch (err) {
      showToast("Delete failed", "error");
    }
  };

  // --- 9. RENDER ---
  return (
    <div className="admin-container">
      <NavBar
        activeTab={activeTab}
        setActiveTab={switchTab}
        onLogout={onLogout}
        userRole={userRole}
        theme={theme} // ✅ Added Theme Prop
        toggleTheme={toggleTheme} // ✅ Added Toggle Prop
      />

      {/* STATS AREA */}
      <div
        className="content-padding"
        style={{
          display: "flex",
          gap: "20px",
          flexWrap: "wrap",
          marginTop: "20px",
        }}
      >
        <StatCard
          title="Total Users"
          value={stats.users}
          icon="👥"
          color="#fff3cd"
          onClick={() => switchTab("users")}
        />
        <StatCard
          title="Active Events"
          value={stats.events}
          icon="📅"
          color="#d1e7dd"
          onClick={() => switchTab("events")}
        />
        <StatCard
          title="Programmes"
          value={stats.programmes}
          icon="🎓"
          color="#cff4fc"
          onClick={() => switchTab("programmes")}
        />
        <StatCard
          title="Registrations"
          value={stats.totalRegistrations}
          icon="📋"
          color="#E6E6FA"
          onClick={() => switchTab("registrations")}
        />
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
        message="Are you sure? This cannot be undone."
        onClose={() => setDeleteModal({ show: false })}
        onConfirm={confirmDelete}
      />

      <div className="content-padding" style={{ marginTop: "30px" }}>
        {activeTab === "users" && (
          <UsersTab
            usersList={users.data}
            page={users.page}
            setPage={users.setPage}
            totalPages={users.totalPages}
            search={users.search}
            setSearch={users.setSearch}
            loading={users.loading}
            approveUser={approveUser}
            toggleAdmin={toggleAdmin}
            toggleEditPermission={toggleEditPermission}
            deleteUserClick={deleteUserClick}
            canEdit={canEdit}
          />
        )}

        {activeTab === "events" && (
          <EventsTab
            eventsList={events.data}
            canEdit={canEdit}
            editingId={editingId}
            eventForm={eventForm}
            setEventForm={setEventForm}
            handleEventSubmit={handleEventSubmit}
            startEditEvent={startEditEvent}
            cancelEditEvent={() => setEditingId(null)}
            deleteEventClick={deleteEventClick}
          />
        )}

        {activeTab === "programmes" && (
          <ProgrammesTab
            programmesList={programmes.data}
            canEdit={canEdit}
            editingId={editingId}
            progForm={progForm}
            setProgForm={setProgForm}
            handleProgrammeSubmit={handleProgrammeSubmit}
            startEditProgramme={startEditProgramme}
            cancelEditProgramme={() => setEditingId(null)}
            deleteProgrammeClick={deleteProgrammeClick}
          />
        )}

        {activeTab === "registrations" && (
          <RegistrationsTab
            registrations={progRegs.data}
            eventRegistrations={eventRegs.data}
            isLoading={progRegs.loading || eventRegs.loading}
            onDelete={handleDeleteRegistration}
            canEdit={canEdit}
            showToast={showToast}
          />
        )}
      </div>
    </div>
  );
}

export default AdminDashboard;
