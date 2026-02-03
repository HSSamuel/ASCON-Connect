import React, { useState, useEffect } from "react";
import {
  BrowserRouter as Router,
  Routes,
  Route,
  Navigate,
} from "react-router-dom";
import AdminDashboard from "./AdminDashboard";
import Login from "./Login";
import ResetPassword from "./pages/ResetPassword";
import VerificationPage from "./pages/VerificationPage";
import { jwtDecode } from "jwt-decode"; // Ensure this is installed

function App() {
  const [token, setToken] = useState(null);
  // ✅ IMPROVEMENT: Add loading state to prevent "Flash of Unauthenticated Content"
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const storedToken = localStorage.getItem("auth_token");
    if (storedToken) {
      try {
        // Optional: Check expiration before setting
        const decoded = jwtDecode(storedToken);
        const currentTime = Date.now() / 1000;

        if (decoded.exp < currentTime) {
          console.warn("Stored token is expired.");
          localStorage.removeItem("auth_token");
        } else {
          setToken(storedToken);
        }
      } catch (e) {
        console.error("Invalid token format in storage.");
        localStorage.removeItem("auth_token");
      }
    }
    setIsLoading(false);
  }, []);

  const handleLogin = (newToken) => {
    localStorage.setItem("auth_token", newToken);
    setToken(newToken);
  };

  const handleLogout = () => {
    localStorage.removeItem("auth_token");
    setToken(null);
  };

  // ✅ Show simple loader while checking session
  if (isLoading) {
    return (
      <div
        style={{
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          height: "100vh",
          background: "#f4f6f9",
        }}
      >
        <div className="spinner-border text-primary" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    );
  }

  return (
    <Router>
      <div className="App">
        <Routes>
          {/* Public Verification Route */}
          <Route path="/verify/:id" element={<VerificationPage />} />

          {/* Reset Password */}
          <Route path="/reset-password" element={<ResetPassword />} />

          {/* Login */}
          <Route
            path="/login"
            element={
              !token ? (
                <Login onLogin={handleLogin} />
              ) : (
                <Navigate to="/" replace />
              )
            }
          />

          {/* Protected Dashboard */}
          <Route
            path="/"
            element={
              token ? (
                <AdminDashboard token={token} onLogout={handleLogout} />
              ) : (
                <Navigate to="/login" replace />
              )
            }
          />

          {/* Catch-all */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
