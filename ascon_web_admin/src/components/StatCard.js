import React from "react";
import "./StatCard.css"; // We will create this next

function StatCard({ title, value, icon, color }) {
  return (
    <div className="stat-card">
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
