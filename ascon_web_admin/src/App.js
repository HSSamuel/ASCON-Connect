import React, { useState } from "react";
import {
  BrowserRouter as Router,
  Routes,
  Route,
  Navigate,
} from "react-router-dom";
import AdminDashboard from "./AdminDashboard";
import Login from "./Login";
import ResetPassword from "./pages/ResetPassword";
import VerificationPage from "./pages/VerificationPage"; // ✅ Import the new page

function App() {
  // Initialize state directly from localStorage
  const [token, setToken] = useState(localStorage.getItem("auth_token"));

  const handleLogin = (newToken) => {
    localStorage.setItem("auth_token", newToken);
    setToken(newToken);
  };

  const handleLogout = () => {
    localStorage.removeItem("auth_token");
    setToken(null);
  };

  return (
    <Router>
      <div className="App">
        <Routes>
          {/* ✅ PUBLIC ROUTE: Verification Page 
             This allows anyone (Security Guards) to scan the QR code without logging in.
          */}
          <Route path="/verify/:id" element={<VerificationPage />} />

          {/* Route: Reset Password */}
          <Route path="/reset-password" element={<ResetPassword />} />

          {/* Route: Login */}
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

          {/* Route: Dashboard (Protected) */}
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
