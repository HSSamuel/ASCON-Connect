import React, { useMemo, useEffect, useReducer } from "react";
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

// --- 1. REDUCER FOR STATE MANAGEMENT ---
const initialState = {
  activeTab: "users",
  refreshCount: 0,
  toast: null,
  theme: localStorage.getItem("theme") || "light",
  deleteModal: { show: false, id: null, type: null },
  editingId: null,
  eventForm: {
    title: "",
    description: "",
    location: "",
    type: "News",
    image: "",
  },
  progForm: {
    title: "",
    code: "",
    description: "",
    duration: "",
    fee: "",
    image: "",
  },
};

function adminReducer(state, action) {
  switch (action.type) {
    case "SET_TAB":
      return {
        ...state,
        activeTab: action.payload,
        editingId: null,
        eventForm: initialState.eventForm,
        progForm: initialState.progForm,
      };
    case "TOGGLE_THEME":
      const newTheme = state.theme === "light" ? "dark" : "light";
      localStorage.setItem("theme", newTheme);
      return { ...state, theme: newTheme };
    case "SHOW_TOAST":
      return { ...state, toast: action.payload };
    case "HIDE_TOAST":
      return { ...state, toast: null };
    case "TRIGGER_REFRESH":
      return { ...state, refreshCount: state.refreshCount + 1 };
    case "OPEN_DELETE_MODAL":
      return {
        ...state,
        deleteModal: { show: true, id: action.id, type: action.deleteType },
      };
    case "CLOSE_MODAL":
      return { ...state, deleteModal: initialState.deleteModal };
    case "START_EDIT_EVENT":
      return {
        ...state,
        editingId: action.payload._id,
        eventForm: { ...action.payload, image: action.payload.image || "" },
      };
    case "START_EDIT_PROG":
      return {
        ...state,
        editingId: action.payload._id,
        progForm: { ...action.payload, image: action.payload.image || "" },
      };
    case "UPDATE_EVENT_FORM":
      return { ...state, eventForm: { ...state.eventForm, ...action.payload } };
    case "UPDATE_PROG_FORM":
      return { ...state, progForm: { ...state.progForm, ...action.payload } };
    case "CANCEL_EDIT":
      return {
        ...state,
        editingId: null,
        eventForm: initialState.eventForm,
        progForm: initialState.progForm,
      };
    default:
      return state;
  }
}

function AdminDashboard({ token, onLogout }) {
  const [state, dispatch] = useReducer(adminReducer, initialState);
  const {
    activeTab,
    refreshCount,
    toast,
    theme,
    deleteModal,
    editingId,
    eventForm,
    progForm,
  } = state;

  // --- 2. EFFECTS ---
  useEffect(() => {
    document.body.setAttribute("data-theme", theme);
  }, [theme]);

  // --- 3. HOOKS ---
  const { canEdit, userRole } = useAuth(token, onLogout);
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
  const stats = useStats(BASE_URL, token, refreshCount);

  const API = useMemo(() => {
    const instance = axios.create({
      baseURL: `${BASE_URL}/api`,
      headers: { "auth-token": token },
    });
    instance.interceptors.response.use(
      (res) => res,
      (err) => {
        if (err.response && [401, 403].includes(err.response.status))
          onLogout();
        return Promise.reject(err);
      }
    );
    return instance;
  }, [token, onLogout]);

  // --- 4. HELPERS ---
  const showToast = (message, type = "success") =>
    dispatch({ type: "SHOW_TOAST", payload: { message, type } });

  // --- 5. ACTIONS (Users) ---
  const approveUser = async (id, name) => {
    // OPTIMISTIC UPDATE: Update local UI immediately
    const originalData = [...users.data];
    const optimisticData = users.data.map((u) =>
      u._id === id ? { ...u, isVerified: true } : u
    );

    // Note: This requires your usePaginatedFetch hook to expose a setData method
    if (users.setData) users.setData(optimisticData);

    try {
      await API.put(`/admin/users/${id}/verify`);
      showToast(`${name} verified!`);
      dispatch({ type: "TRIGGER_REFRESH" });
    } catch (err) {
      if (users.setData) users.setData(originalData); // Rollback on failure
      showToast(err.response?.data?.message || "Failed to verify.", "error");
    }
  };

  const toggleAdmin = async (id) => {
    try {
      await API.put(`/admin/users/${id}/toggle-admin`);
      showToast("Admin status updated");
      users.refresh();
    } catch (err) {
      showToast("Update failed.", "error");
    }
  };

  const toggleEditPermission = async (id) => {
    try {
      await API.put(`/admin/users/${id}/toggle-edit`);
      showToast("Permissions updated");
      users.refresh();
    } catch (err) {
      showToast("Update failed.", "error");
    }
  };

  // --- 6. ACTIONS (Events) ---
  const handleEventSubmit = async (e) => {
    e.preventDefault();
    // CLIENT-SIDE VALIDATION
    if (eventForm.title.length < 5)
      return showToast("Title must be at least 5 characters", "error");
    if (eventForm.description.length < 10)
      return showToast("Description too short", "error");

    try {
      if (editingId) {
        await API.put(`/admin/events/${editingId}`, eventForm);
        showToast("Event updated");
      } else {
        await API.post("/admin/events", { ...eventForm, date: new Date() });
        showToast("Event published");
      }
      dispatch({ type: "CANCEL_EDIT" });
      events.refresh();
      dispatch({ type: "TRIGGER_REFRESH" });
    } catch (err) {
      showToast(err.response?.data?.message || "Error saving event", "error");
    }
  };

  // --- 7. SHARED DELETE ---
  const confirmDelete = async () => {
    const { id, type } = deleteModal;
    dispatch({ type: "CLOSE_MODAL" });
    try {
      if (type === "user") await API.delete(`/admin/users/${id}`);
      else if (type === "event") await API.delete(`/admin/events/${id}`);
      else if (type === "programme")
        await API.delete(`/admin/programmes/${id}`);
      else if (type === "reg_prog")
        await API.delete(`/programme-interest/${id}`);
      else if (type === "reg_event")
        await API.delete(`/event-registration/${id}`);

      showToast("Deleted successfully");
      dispatch({ type: "TRIGGER_REFRESH" });
      if (type.startsWith("reg_")) {
        progRegs.refresh();
        eventRegs.refresh();
      } else if (type === "user") users.refresh();
      else if (type === "event") events.refresh();
      else if (type === "programme") programmes.refresh();
    } catch (err) {
      showToast("Delete failed", "error");
    }
  };

  return (
    <div className="admin-container">
      <NavBar
        activeTab={activeTab}
        setActiveTab={(tab) => dispatch({ type: "SET_TAB", payload: tab })}
        onLogout={onLogout}
        userRole={userRole}
        theme={theme}
        toggleTheme={() => dispatch({ type: "TOGGLE_THEME" })}
      />

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
          color={theme === "light" ? "#fff3cd" : "#2c2c2c"}
          onClick={() => dispatch({ type: "SET_TAB", payload: "users" })}
        />
        <StatCard
          title="Active Events"
          value={stats.events}
          icon="📅"
          color="#d1e7dd"
          onClick={() => dispatch({ type: "SET_TAB", payload: "events" })}
        />
        <StatCard
          title="Programmes"
          value={stats.programmes}
          icon="🎓"
          color="#cff4fc"
          onClick={() => dispatch({ type: "SET_TAB", payload: "programmes" })}
        />
        <StatCard
          title="Registrations"
          value={stats.totalRegistrations}
          icon="📋"
          color="#E6E6FA"
          onClick={() =>
            dispatch({ type: "SET_TAB", payload: "registrations" })
          }
        />
      </div>

      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => dispatch({ type: "HIDE_TOAST" })}
        />
      )}

      <ConfirmModal
        isOpen={deleteModal.show}
        title="Confirm Deletion"
        message="Are you sure? This cannot be undone."
        onClose={() => dispatch({ type: "CLOSE_MODAL" })}
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
            deleteUserClick={(id) =>
              dispatch({ type: "OPEN_DELETE_MODAL", id, deleteType: "user" })
            }
            canEdit={canEdit}
          />
        )}

        {activeTab === "events" && (
          <EventsTab
            eventsList={events.data}
            canEdit={canEdit}
            editingId={editingId}
            eventForm={eventForm}
            setEventForm={(data) =>
              dispatch({ type: "UPDATE_EVENT_FORM", payload: data })
            }
            handleEventSubmit={handleEventSubmit}
            startEditEvent={(evt) => {
              dispatch({ type: "START_EDIT_EVENT", payload: evt });
              window.scrollTo(0, 0);
            }}
            cancelEditEvent={() => dispatch({ type: "CANCEL_EDIT" })}
            deleteEventClick={(id) =>
              dispatch({ type: "OPEN_DELETE_MODAL", id, deleteType: "event" })
            }
          />
        )}

        {activeTab === "programmes" && (
          <ProgrammesTab
            programmesList={programmes.data}
            canEdit={canEdit}
            editingId={editingId}
            progForm={progForm}
            setProgForm={(data) =>
              dispatch({ type: "UPDATE_PROG_FORM", payload: data })
            }
            handleProgrammeSubmit={async (e) => {
              e.preventDefault();
              try {
                if (editingId)
                  await API.put(`/admin/programmes/${editingId}`, progForm);
                else await API.post("/admin/programmes", progForm);
                showToast("Programme saved");
                dispatch({ type: "CANCEL_EDIT" });
                programmes.refresh();
                dispatch({ type: "TRIGGER_REFRESH" });
              } catch (err) {
                showToast("Error saving programme", "error");
              }
            }}
            startEditProgramme={(prog) => {
              dispatch({ type: "START_EDIT_PROG", payload: prog });
              window.scrollTo(0, 0);
            }}
            cancelEditProgramme={() => dispatch({ type: "CANCEL_EDIT" })}
            deleteProgrammeClick={(id) =>
              dispatch({
                type: "OPEN_DELETE_MODAL",
                id,
                deleteType: "programme",
              })
            }
          />
        )}

        {activeTab === "registrations" && (
          <RegistrationsTab
            registrations={progRegs.data}
            eventRegistrations={eventRegs.data}
            isLoading={progRegs.loading || eventRegs.loading}
            onDelete={(id, type) =>
              dispatch({
                type: "OPEN_DELETE_MODAL",
                id,
                deleteType: type === "programmes" ? "reg_prog" : "reg_event",
              })
            }
            canEdit={canEdit}
            showToast={showToast}
          />
        )}
      </div>
    </div>
  );
}

export default AdminDashboard;
