import React from "react";
import "./StatCard.css";

function StatCard({ title, value, icon, color, onClick }) {
  return (
    <div
      className="stat-card"
      onClick={onClick}
      style={{ cursor: onClick ? "pointer" : "default" }} // ✅ Add pointer cursor
    >
      <div className="stat-icon-container" style={{ backgroundColor: color }}>
        <span className="stat-icon">{icon}</span>
      </div>
      <div className="stat-info">
        <p className="stat-title">{title}</p>
        <h3 className="stat-value">{value}</h3>
      </div>
    </div>
  );
}

export default StatCard;
