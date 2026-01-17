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

import { useAuth } from "./hooks/useAuth";
import { useStats } from "./hooks/useStats";

const BASE_URL =
  process.env.REACT_APP_API_URL || "https://ascon-st50.onrender.com";

function AdminDashboard({ token, onLogout }) {
  const [activeTab, setActiveTab] = useState("users");
  const [theme, setTheme] = useState(localStorage.getItem("theme") || "light");

  // ✅ 1. CREATE A REFRESH TRIGGER
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  // ✅ 2. PASS TRIGGER TO useStats (This forces stats to re-fetch when trigger changes)
  const { canEdit, userRole } = useAuth(token, onLogout);
  const stats = useStats(BASE_URL, token, refreshTrigger);

  useEffect(() => {
    document.body.setAttribute("data-theme", theme);
  }, [theme]);

  const toggleTheme = () => {
    const newTheme = theme === "light" ? "dark" : "light";
    localStorage.setItem("theme", newTheme);
    setTheme(newTheme);
  };

  // ✅ 3. HELPER FUNCTION TO UPDATE STATS
  const refreshStats = () => {
    setRefreshTrigger((prev) => prev + 1);
  };

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

        {/* FACILITIES STAT CARD */}
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

        {/* ✅ 4. PASS THE REFRESH FUNCTION TO FACILITIES TAB */}
        {activeTab === "facilities" && (
          <FacilitiesTab onRefreshStats={refreshStats} />
        )}

        {activeTab === "registrations" && (
          <RegistrationsManager token={token} canEdit={canEdit} />
        )}
      </div>
    </div>
  );
}

export default AdminDashboard;
