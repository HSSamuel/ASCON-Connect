import React from "react";
import "./FacilitiesTab.css"; // Ensure you create/update this CSS

function FacilitiesTab({ facilitiesList, deleteFacility, toggleAvailability }) {
  if (!facilitiesList || facilitiesList.length === 0) {
    return (
      <div className="empty-state">No Facilities Found. Add one above!</div>
    );
  }

  return (
    <div className="facilities-grid">
      {facilitiesList.map((facility) => (
        <div key={facility._id} className="facility-card">
          <div
            className="facility-image"
            style={{
              backgroundImage: `url(${
                facility.image || "/default-building.png"
              })`,
            }}
          >
            <span
              className={`status-badge ${
                facility.isAvailable ? "open" : "closed"
              }`}
            >
              {facility.isAvailable ? "Available" : "Booked"}
            </span>
          </div>

          <div className="facility-content">
            <h3>{facility.name}</h3>
            <p className="capacity">
              👥 Capacity: {facility.capacity || "N/A"}
            </p>
            <p className="desc">{facility.description?.substring(0, 60)}...</p>

            <div className="facility-actions">
              <button
                onClick={() => toggleAvailability(facility._id)}
                className="btn-toggle"
              >
                {facility.isAvailable ? "Mark Booked" : "Mark Open"}
              </button>
              <button
                onClick={() => deleteFacility(facility._id)}
                className="btn-delete"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

export default FacilitiesTab;
