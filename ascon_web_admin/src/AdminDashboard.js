import React, { useState, useEffect } from "react";
import axios from "axios";

function AdminDashboard() {
  const [pendingUsers, setPendingUsers] = useState([]);
  const [message, setMessage] = useState("");

  // 1. Fetch the list when the page loads
  useEffect(() => {
    fetchPendingUsers();
  }, []);

  const fetchPendingUsers = async () => {
    try {
      // Connect to your Backend to get pending users
      const res = await axios.get("http://localhost:5000/api/admin/pending");
      setPendingUsers(res.data);
    } catch (err) {
      console.error(err);
      setMessage("Error connecting to server. Is the backend running?");
    }
  };

  // 2. The Logic to Approve a User
  const approveUser = async (id, name) => {
    try {
      await axios.put(`http://localhost:5000/api/admin/verify/${id}`);
      setMessage(`Success! ${name} is now verified.`);

      // Refresh the list automatically to show they are gone
      fetchPendingUsers();
    } catch (err) {
      console.error(err);
      setMessage("Failed to approve user.");
    }
  };

  return (
    <div style={{ padding: "50px", fontFamily: "Arial, sans-serif" }}>
      <h1 style={{ color: "#006400" }}>ASCON Admin Portal</h1>
      <p>Manage pending alumni registrations.</p>

      {/* Message Box */}
      {message && (
        <div
          style={{
            padding: "15px",
            backgroundColor: "#e6ffe6",
            color: "#006400",
            marginBottom: "20px",
            borderRadius: "5px",
          }}
        >
          {message}
        </div>
      )}

      {/* The Table */}
      {pendingUsers.length === 0 ? (
        <div
          style={{
            padding: "20px",
            backgroundColor: "#f8f9fa",
            borderRadius: "8px",
          }}
        >
          <h3>No pending approvals. All caught up! ✅</h3>
        </div>
      ) : (
        <table
          style={{
            width: "100%",
            borderCollapse: "collapse",
            marginTop: "20px",
          }}
        >
          <thead>
            <tr
              style={{
                backgroundColor: "#006400",
                color: "white",
                textAlign: "left",
              }}
            >
              <th style={{ padding: "12px" }}>Full Name</th>
              <th style={{ padding: "12px" }}>Email</th>
              <th style={{ padding: "12px" }}>Year</th>
              <th style={{ padding: "12px" }}>Programme</th>
              <th style={{ padding: "12px" }}>Action</th>
            </tr>
          </thead>
          <tbody>
            {pendingUsers.map((user) => (
              <tr key={user._id} style={{ borderBottom: "1px solid #ddd" }}>
                <td style={{ padding: "12px" }}>{user.fullName}</td>
                <td style={{ padding: "12px" }}>{user.email}</td>
                <td style={{ padding: "12px" }}>{user.yearOfAttendance}</td>
                <td style={{ padding: "12px" }}>{user.programmeTitle}</td>
                <td style={{ padding: "12px" }}>
                  <button
                    onClick={() => approveUser(user._id, user.fullName)}
                    style={{
                      backgroundColor: "#D4AF37", // Gold button
                      color: "white",
                      fontWeight: "bold",
                      border: "none",
                      padding: "8px 16px",
                      cursor: "pointer",
                      borderRadius: "4px",
                    }}
                  >
                    APPROVE
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

export default AdminDashboard;
