import React, { useState } from "react";

function RegistrationsTab({ registrations, eventRegistrations, isLoading }) {
  // ✅ Toggle State: 'programmes' or 'events'
  const [view, setView] = useState("programmes");

  if (isLoading) {
    return (
      <div style={{ padding: "40px", textAlign: "center", color: "#666" }}>
        Loading registrations...
      </div>
    );
  }

  // Helper to choose which list to show based on the toggle
  const activeList = view === "programmes" ? registrations : eventRegistrations;

  return (
    <div>
      {/* 1. HEADER & TOGGLE */}
      <div
        className="empty-state"
        style={{ textAlign: "center", marginBottom: "30px" }}
      >
        <h2 style={{ margin: "0 0 10px 0", color: "#1B5E3A" }}>
          📋 Registrations Viewer
        </h2>
        <p style={{ color: "#666", margin: 0 }}>
          View users who have expressed interest via the mobile app.
        </p>

        {/* ✅ TOGGLE BUTTONS */}
        <div
          style={{
            marginTop: "20px",
            display: "inline-flex",
            background: "#f0f0f0",
            borderRadius: "8px",
            padding: "4px",
          }}
        >
          <button
            onClick={() => setView("programmes")}
            style={{
              padding: "8px 20px",
              border: "none",
              borderRadius: "6px",
              cursor: "pointer",
              background: view === "programmes" ? "white" : "transparent",
              color: view === "programmes" ? "#1B5E3A" : "#666",
              fontWeight: view === "programmes" ? "bold" : "normal",
              boxShadow:
                view === "programmes" ? "0 2px 4px rgba(0,0,0,0.1)" : "none",
              transition: "all 0.2s",
            }}
          >
            Programmes ({registrations.length})
          </button>
          <button
            onClick={() => setView("events")}
            style={{
              padding: "8px 20px",
              border: "none",
              borderRadius: "6px",
              cursor: "pointer",
              background: view === "events" ? "white" : "transparent",
              color: view === "events" ? "#1B5E3A" : "#666",
              fontWeight: view === "events" ? "bold" : "normal",
              boxShadow:
                view === "events" ? "0 2px 4px rgba(0,0,0,0.1)" : "none",
              transition: "all 0.2s",
            }}
          >
            Events ({eventRegistrations.length})
          </button>
        </div>
      </div>

      {/* 2. DATA TABLE */}
      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Applicant</th>
              <th>Contact</th>
              {/* ✅ Dynamic Column Header */}
              <th>
                {view === "programmes" ? "Programme Title" : "Event / Type"}
              </th>
              <th>Organization</th>
              <th>Location</th>
              {/* ✅ Show "Special Req" only for Events */}
              {view === "events" && <th>Special Req</th>}
            </tr>
          </thead>
          <tbody>
            {activeList.length === 0 ? (
              <tr>
                <td
                  colSpan={view === "events" ? 7 : 6}
                  style={{
                    textAlign: "center",
                    padding: "40px",
                    color: "#888",
                  }}
                >
                  No {view} registrations found yet.
                </td>
              </tr>
            ) : (
              activeList.map((reg) => (
                <tr key={reg._id}>
                  {/* DATE */}
                  <td
                    style={{
                      fontSize: "12px",
                      color: "#666",
                      whiteSpace: "nowrap",
                    }}
                  >
                    {new Date(reg.createdAt).toLocaleDateString()} <br />
                    {new Date(reg.createdAt).toLocaleTimeString([], {
                      hour: "2-digit",
                      minute: "2-digit",
                    })}
                  </td>

                  {/* APPLICANT */}
                  <td>
                    <div style={{ fontWeight: "bold", color: "#333" }}>
                      {reg.fullName}
                    </div>
                    <div style={{ fontSize: "12px", color: "#888" }}>
                      {reg.sex}
                    </div>
                  </td>

                  {/* CONTACT */}
                  <td>
                    <div style={{ fontSize: "13px" }}>📧 {reg.email}</div>
                    <div style={{ fontSize: "13px", marginTop: "2px" }}>
                      📞 {reg.phone}
                    </div>
                  </td>

                  {/* TITLE (Handles both Programme and Event fields) */}
                  <td>
                    <span
                      className="tag"
                      style={{
                        backgroundColor:
                          view === "events" ? "#e3f2fd" : "#e8f5e9",
                        color: view === "events" ? "#0d47a1" : "#1b5e20",
                        padding: "4px 8px",
                        borderRadius: "4px",
                        fontSize: "12px",
                        fontWeight: "bold",
                      }}
                    >
                      {reg.programmeTitle || reg.eventTitle}
                    </span>
                    {/* Show Badge for Event Type */}
                    {reg.eventType && (
                      <div
                        style={{
                          fontSize: "10px",
                          marginTop: "6px",
                          color: "#666",
                          textTransform: "uppercase",
                          fontWeight: "bold",
                        }}
                      >
                        TYPE: {reg.eventType}
                      </div>
                    )}
                  </td>

                  {/* EMPLOYMENT */}
                  <td style={{ fontSize: "13px" }}>
                    <div style={{ fontWeight: "bold" }}>
                      {reg.sponsoringOrganisation || reg.organization}
                    </div>
                    <div style={{ color: "#666", fontSize: "12px" }}>
                      {reg.jobTitle}
                    </div>
                  </td>

                  {/* LOCATION (Country only for Events usually, Full address for Programmes) */}
                  <td style={{ fontSize: "13px" }}>
                    {reg.city ? `${reg.city}, ` : ""}
                    <span style={{ fontWeight: "500" }}>
                      {reg.country || "N/A"}
                    </span>
                  </td>

                  {/* SPECIAL REQ (Events Only) */}
                  {view === "events" && (
                    <td
                      style={{
                        fontSize: "12px",
                        color: "#d32f2f",
                        maxWidth: "150px",
                      }}
                    >
                      {reg.specialRequirements ? (
                        <span
                          style={{
                            background: "#ffebee",
                            padding: "2px 6px",
                            borderRadius: "4px",
                          }}
                        >
                          {reg.specialRequirements}
                        </span>
                      ) : (
                        <span style={{ color: "#ccc" }}>-</span>
                      )}
                    </td>
                  )}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default RegistrationsTab;
