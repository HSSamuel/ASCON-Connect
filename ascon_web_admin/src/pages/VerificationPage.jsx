import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import axios from "axios";
import logo from "../assets/logo.png"; // Make sure logo.png is in src/assets

export default function VerificationPage() {
  const { id } = useParams(); // Gets "ASC-2026-0052" from URL
  const [status, setStatus] = useState("loading"); // loading, valid, invalid
  const [data, setData] = useState(null);

  // ✅ LIVE URL CONFIGURATION
  // It tries to use the local environment variable first.
  // If that fails, it falls back to your Live Render URL.
  const BASE_URL =
    process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

  useEffect(() => {
    const verifyUser = async () => {
      try {
        // Convert "ASC-2026-0052" -> "ASC/2026/0052" handled by backend logic or here
        // We send it as is, and let the backend handle the replace(/-/g, "/") logic we just added
        const res = await axios.get(`${BASE_URL}/api/directory/verify/${id}`);
        setData(res.data);
        setStatus("valid");
      } catch (err) {
        console.error(err);
        setStatus("invalid");
      }
    };

    if (id) verifyUser();
  }, [id, BASE_URL]);

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <img
          src={logo}
          alt="ASCON Logo"
          style={{ width: 80, marginBottom: 20 }}
        />

        {status === "loading" && <h3>Verifying ID...</h3>}

        {status === "invalid" && (
          <>
            <h2
              style={{
                color: "red",
                border: "2px solid red",
                padding: "10px",
                display: "inline-block",
              }}
            >
              ❌ INVALID ID
            </h2>
            <p style={{ marginTop: 20 }}>
              The ID <b>{id}</b> could not be verified in our database.
            </p>
            <p style={{ color: "red" }}>Please contact the Secretariat.</p>
          </>
        )}

        {status === "valid" && data && (
          <>
            <h2
              style={{
                color: "#1B5E3A",
                border: "2px solid #1B5E3A",
                padding: "10px",
                display: "inline-block",
                borderRadius: "8px",
              }}
            >
              ✅ VERIFIED ALUMNUS
            </h2>

            <img
              src={data.profilePicture || "https://via.placeholder.com/150"}
              alt="Profile"
              style={styles.avatar}
            />

            <h2 style={{ margin: "10px 0", color: "#333" }}>
              {data.fullName.toUpperCase()}
            </h2>

            <div style={styles.infoRow}>
              <span style={styles.label}>Programme:</span>
              <span style={styles.value}>{data.programmeTitle}</span>
            </div>

            <div style={styles.infoRow}>
              <span style={styles.label}>Class Set:</span>
              <span style={styles.value}>{data.yearOfAttendance}</span>
            </div>

            <div style={styles.infoRow}>
              <span style={styles.label}>Alumni ID:</span>
              <span style={styles.value} className="id-text">
                {data.alumniId}
              </span>
            </div>

            <div style={styles.badge}>ACTIVE MEMBER</div>

            <p style={{ fontSize: 12, color: "#999", marginTop: 20 }}>
              Administrative Staff College of Nigeria (ASCON)
            </p>
          </>
        )}
      </div>
    </div>
  );
}

// Simple Inline CSS Styles
const styles = {
  container: {
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    minHeight: "100vh",
    backgroundColor: "#f0f2f5",
    padding: "20px",
  },
  card: {
    background: "white",
    padding: "40px",
    borderRadius: "15px",
    boxShadow: "0 10px 25px rgba(0,0,0,0.1)",
    textAlign: "center",
    maxWidth: "400px",
    width: "100%",
  },
  avatar: {
    width: "120px",
    height: "120px",
    borderRadius: "50%",
    objectFit: "cover",
    margin: "20px auto",
    border: "4px solid #1B5E3A",
    boxShadow: "0 4px 10px rgba(0,0,0,0.1)",
  },
  badge: {
    marginTop: "25px",
    display: "inline-block",
    padding: "8px 20px",
    background: "#1B5E3A",
    color: "white",
    borderRadius: "30px",
    fontSize: "14px",
    fontWeight: "bold",
    letterSpacing: "1px",
  },
  infoRow: {
    display: "flex",
    flexDirection: "column",
    margin: "10px 0",
    alignItems: "center",
  },
  label: {
    fontSize: "12px",
    color: "#777",
    textTransform: "uppercase",
    letterSpacing: "0.5px",
  },
  value: {
    fontSize: "16px",
    fontWeight: "600",
    color: "#333",
  },
};
