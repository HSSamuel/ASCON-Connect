import React, { useState, useEffect } from "react";
import "./App.css";
import NavBar from "./components/NavBar";
import StatCard from "./components/StatCard";

// ✅ Import ALL Smart Managers
import UsersManager from "./pages/UsersManager";
import EventsManager from "./pages/EventsManager";
import ProgrammesManager from "./pages/ProgrammesManager";
import RegistrationsManager from "./pages/RegistrationsManager";
import JobsManager from "./pages/JobsManager";
import FacilitiesTab from "./components/FacilitiesTab";
import DocumentsManager from "./pages/DocumentsManager";

import { useAuth } from "./hooks/useAuth";
// Note: useStats is now used inside the Context, not here directly
import { DashboardProvider, useDashboard } from "./context/DashboardContext";

// Internal Component to consume Context
const DashboardContent = ({
  token,
  onLogout,
  activeTab,
  setActiveTab,
  theme,
  toggleTheme,
  canEdit,
  userRole,
}) => {
  const { stats } = useDashboard(); // ✅ Clean access to stats

  return (
    <div className="admin-container">
      <NavBar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        onLogout={onLogout}
        userRole={userRole}
        theme={theme}
        toggleTheme={toggleTheme}
      />

      {/* STATS BAR */}
      <div
        className="content-padding stats-grid-mobile"
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
          onClick={() => setActiveTab("users")}
        />
        <StatCard
          title="Active Events"
          value={stats.events}
          icon="📅"
          color="#d1e7dd"
          onClick={() => setActiveTab("events")}
        />
        <StatCard
          title="Programmes"
          value={stats.programmes}
          icon="🎓"
          color="#cff4fc"
          onClick={() => setActiveTab("programmes")}
        />

        <StatCard
          title="Jobs/Careers"
          value={stats.jobs || 0}
          icon="💼"
          color={theme === "light" ? "#e2e3e5" : "#3a3a3a"}
          onClick={() => setActiveTab("jobs")}
        />

        <StatCard
          title="Facilities"
          value={stats.facilities || 0}
          icon="🏢"
          color="#ffe5d0"
          onClick={() => setActiveTab("facilities")}
        />

        <StatCard
          title="Registrations"
          value={stats.totalRegistrations}
          icon="📋"
          color="#E6E6FA"
          onClick={() => setActiveTab("registrations")}
        />
      </div>

      <div
        className="content-padding"
        style={{ marginTop: "30px", paddingBottom: "20px" }}
      >
        {activeTab === "users" && (
          <UsersManager token={token} canEdit={canEdit} />
        )}

        {activeTab === "events" && (
          <EventsManager token={token} canEdit={canEdit} />
        )}

        {activeTab === "programmes" && (
          <ProgrammesManager token={token} canEdit={canEdit} />
        )}

        {activeTab === "jobs" && (
          <JobsManager token={token} canEdit={canEdit} />
        )}

        {/* ✅ FacilitiesTab no longer needs onRefreshStats prop */}
        {activeTab === "facilities" && <FacilitiesTab />}

        {activeTab === "registrations" && (
          <RegistrationsManager token={token} canEdit={canEdit} />
        )}

        {activeTab === "documents" && (
          <DocumentsManager token={token} canEdit={canEdit} />
        )}
      </div>
    </div>
  );
};

function AdminDashboard({ token, onLogout }) {
  const [activeTab, setActiveTab] = useState("users");
  const [theme, setTheme] = useState(localStorage.getItem("theme") || "light");
  const { canEdit, userRole } = useAuth(token, onLogout);

  useEffect(() => {
    document.body.setAttribute("data-theme", theme);
  }, [theme]);

  const toggleTheme = () => {
    const newTheme = theme === "light" ? "dark" : "light";
    localStorage.setItem("theme", newTheme);
    setTheme(newTheme);
  };

  return (
    // ✅ WRAP ENTIRE DASHBOARD IN PROVIDER
    <DashboardProvider>
      <DashboardContent
        token={token}
        onLogout={onLogout}
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        theme={theme}
        toggleTheme={toggleTheme}
        canEdit={canEdit}
        userRole={userRole}
      />
    </DashboardProvider>
  );
}

export default AdminDashboard;
