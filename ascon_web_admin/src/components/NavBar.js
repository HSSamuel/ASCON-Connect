import React, { useState } from "react";
import logo from "../assets/logo.png";
import "../App.css"; // Ensure CSS is imported

const NavBar = ({ activeTab, setActiveTab, onLogout, userRole }) => {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  const navItems = ["users", "events", "programmes"];

  const handleTabClick = (tab) => {
    setActiveTab(tab);
    setIsMobileMenuOpen(false); // Close menu on selection (mobile)
  };

  return (
    <nav className="navbar">
      {/* 1. LOGO & BRAND */}
      <div className="navbar-brand">
        <img src={logo} alt="ASCON Logo" className="navbar-logo" />
        <div className="navbar-title-container">
          <h1 className="navbar-title">ASCON ADMIN</h1>
          <span className="navbar-subtitle">{userRole}</span>
        </div>
      </div>

      {/* 2. HAMBURGER ICON (Mobile Only) */}
      <div
        className="navbar-hamburger"
        onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
      >
        <span className={`bar ${isMobileMenuOpen ? "open" : ""}`}></span>
        <span className={`bar ${isMobileMenuOpen ? "open" : ""}`}></span>
        <span className={`bar ${isMobileMenuOpen ? "open" : ""}`}></span>
      </div>

      {/* 3. NAV LINKS & LOGOUT */}
      <div className={`navbar-links ${isMobileMenuOpen ? "active" : ""}`}>
        {navItems.map((tab) => (
          <button
            key={tab}
            onClick={() => handleTabClick(tab)}
            className={`nav-item ${activeTab === tab ? "active" : ""}`}
          >
            {tab.toUpperCase()}
          </button>
        ))}

        <button onClick={onLogout} className="nav-item logout-btn">
          LOGOUT
        </button>
      </div>
    </nav>
  );
};

export default NavBar;
