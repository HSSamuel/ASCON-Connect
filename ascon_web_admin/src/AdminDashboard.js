import React, { useState, useEffect } from "react";
import "./App.css";
import NavBar from "./components/NavBar";
import StatCard from "./components/StatCard";

// ✅ Import ALL Smart Managers
import UsersManager from "./pages/UsersManager";
import EventsManager from "./pages/EventsManager";
import ProgrammesManager from "./pages/ProgrammesManager";
import RegistrationsManager from "./pages/RegistrationsManager";

import { useAuth } from "./hooks/useAuth";
import { useStats } from "./hooks/useStats";

const BASE_URL = process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

function AdminDashboard({ token, onLogout }) {
  const [activeTab, setActiveTab] = useState("users");
  const [theme, setTheme] = useState(localStorage.getItem("theme") || "light");

  // ✅ 1. GLOBAL LOGIC (Auth & Stats only)
  const { canEdit, userRole } = useAuth(token, onLogout);
  const stats = useStats(BASE_URL, token, 0);

  useEffect(() => {
    document.body.setAttribute("data-theme", theme);
  }, [theme]);

  const toggleTheme = () => {
    const newTheme = theme === "light" ? "dark" : "light";
    localStorage.setItem("theme", newTheme);
    setTheme(newTheme);
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
        {/* ✅ RENDER MANAGERS */}
        {activeTab === "users" && (
          <UsersManager token={token} canEdit={canEdit} />
        )}

        {activeTab === "events" && (
          <EventsManager token={token} canEdit={canEdit} />
        )}

        {activeTab === "programmes" && (
          <ProgrammesManager token={token} canEdit={canEdit} />
        )}

        {activeTab === "registrations" && (
          <RegistrationsManager token={token} canEdit={canEdit} />
        )}
      </div>
    </div>
  );
}

export default AdminDashboard;
