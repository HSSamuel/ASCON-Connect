import React, { useState } from "react";
import "./NavBar.css";

function NavBar({ activeTab, setActiveTab, onLogout, userRole }) {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const handleTabClick = (tab) => {
    setActiveTab(tab);
    setIsMenuOpen(false);
  };

  return (
    <>
      {/* ==============================
          1. DESKTOP NAVIGATION (Top Bar)
         ============================== */}
      <nav className="desktop-nav">
        <div className="nav-brand">
          {/* ✅ REPLACED ICON WITH LOGO */}
          <img
            src="/logo.png" // ⚠️ Ensure you have a 'logo.png' in your 'public' folder
            alt="ASCON Logo"
            className="brand-logo"
          />
          <span className="brand-text">ASCON Admin</span>
        </div>

        {/* Links are now pushed to the right via CSS */}
        <div className="nav-links">
          <button
            className={activeTab === "users" ? "active" : ""}
            onClick={() => handleTabClick("users")}
          >
            👥 Users
          </button>
          <button
            className={activeTab === "events" ? "active" : ""}
            onClick={() => handleTabClick("events")}
          >
            📅 Events
          </button>
          <button
            className={activeTab === "programmes" ? "active" : ""}
            onClick={() => handleTabClick("programmes")}
          >
            🎓 Programmes
          </button>
          <button
            className={activeTab === "registrations" ? "active" : ""}
            onClick={() => handleTabClick("registrations")}
          >
            📋 Registrations
          </button>
        </div>

        <button className="logout-btn" onClick={onLogout}>
          Logout ↪
        </button>
      </nav>

      {/* ==============================
          2. MOBILE MENU OVERLAY
         ============================== */}
      {isMenuOpen && (
        <div className="mobile-menu-overlay">
          <div className="mobile-menu-content">
            <h3>Menu</h3>
            <button onClick={() => handleTabClick("users")}>
              👥 Users Management
            </button>
            <button onClick={() => handleTabClick("events")}>
              📅 Events Management
            </button>
            <button onClick={() => handleTabClick("programmes")}>
              🎓 Programmes
            </button>
            <button onClick={() => handleTabClick("registrations")}>
              📋 Registrations
            </button>
            <hr />
            <button className="mobile-logout" onClick={onLogout}>
              🚪 Logout
            </button>
            <button className="close-menu" onClick={() => setIsMenuOpen(false)}>
              ▼ Close
            </button>
          </div>
        </div>
      )}

      {/* ==============================
          3. MOBILE BOTTOM BAR
         ============================== */}
      <div className="mobile-bottom-bar">
        {/* 1. USERS TAB (Was Home) */}
        <div
          className="bottom-nav-item"
          onClick={() => handleTabClick("users")}
        >
          <span
            className={`icon ${activeTab === "users" ? "active-icon" : ""}`}
          >
            👥 {/* ✅ Changed Icon from 🏠 to 👥 */}
          </span>
          <span className="label">Users</span> {/* ✅ Renamed from "Home" */}
        </div>

        {/* 2. EVENTS TAB */}
        <div
          className="bottom-nav-item"
          onClick={() => handleTabClick("events")}
        >
          <span
            className={`icon ${activeTab === "events" ? "active-icon" : ""}`}
          >
            📅
          </span>
          <span className="label">Events</span>
        </div>

        {/* CENTER MENU BUTTON */}
        <div className="fab-container">
          <div className="fab-notch"></div>
          <button
            className="fab-btn"
            onClick={() => setIsMenuOpen(!isMenuOpen)}
          >
            <span className="fab-icon">☰</span>
          </button>
          <span className="fab-label">Menu</span>
        </div>

        {/* 3. PROGRAMMES TAB (Was Library) */}
        <div
          className="bottom-nav-item"
          onClick={() => handleTabClick("programmes")}
        >
          <span
            className={`icon ${
              activeTab === "programmes" ? "active-icon" : ""
            }`}
          >
            🎓 {/* ✅ Changed Icon from 📂 to 🎓 */}
          </span>
          <span className="label">Programmes</span>{" "}
          {/* ✅ Renamed from "Library" */}
        </div>

        {/* 4. REGISTRATIONS TAB (Was Contact) */}
        <div
          className="bottom-nav-item"
          onClick={() => handleTabClick("registrations")}
        >
          <span
            className={`icon ${
              activeTab === "registrations" ? "active-icon" : ""
            }`}
          >
            📋 {/* ✅ Changed Icon from ✈️ to 📋 */}
          </span>
          <span className="label">Regs</span>{" "}
          {/* ✅ Renamed from "Contact" (Shortened for mobile space) */}
        </div>
      </div>
    </>
  );
}

export default NavBar;
