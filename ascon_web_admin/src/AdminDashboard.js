import React, { useState, useEffect } from "react";
import "./App.css";
import NavBar from "./components/NavBar";
import StatCard from "./components/StatCard";

// ✅ Import ALL Smart Managers including the new DocumentsManager
import UsersManager from "./pages/UsersManager";
import EventsManager from "./pages/EventsManager";
import ProgrammesManager from "./pages/ProgrammesManager";
import RegistrationsManager from "./pages/RegistrationsManager";
import JobsManager from "./pages/JobsManager";
import FacilitiesTab from "./components/FacilitiesTab";
import DocumentsManager from "./pages/DocumentsManager"; // ✅ NEW IMPORT

import { useAuth } from "./hooks/useAuth";
import { useStats } from "./hooks/useStats";

function AdminDashboard({ token, onLogout }) {
  const [activeTab, setActiveTab] = useState("users");
  const [theme, setTheme] = useState(localStorage.getItem("theme") || "light");

  // ✅ 1. CREATE A REFRESH TRIGGER
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { canEdit, userRole } = useAuth(token, onLogout);
  const stats = useStats(refreshTrigger);

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

        {/* OPTIONAL: Document Stats Card (You can add this if your stats API returns it) */}
        {/* <StatCard
          title="Doc Requests"
          value={stats.documentRequests || 0}
          icon="📄"
          color="#f8d7da"
          onClick={() => setActiveTab("documents")}
        /> */}
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

        {/* ✅ 5. RENDER DOCUMENTS MANAGER */}
        {activeTab === "documents" && (
          <DocumentsManager token={token} canEdit={canEdit} />
        )}
      </div>
    </div>
  );
}

export default AdminDashboard;
