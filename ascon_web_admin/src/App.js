import React, { useState } from "react";
import {
  BrowserRouter as Router,
  Routes,
  Route,
  Navigate,
} from "react-router-dom";
import AdminDashboard from "./AdminDashboard";
import Login from "./Login";
import ResetPassword from "./pages/ResetPassword"; // ✅ Import the new page

function App() {
  // Initialize state directly from localStorage to prevent "flicker" on reload
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
          {/* ✅ Route 1: Reset Password 
             This matches the link sent in the email (e.g., /reset-password?token=...)
          */}
          <Route path="/reset-password" element={<ResetPassword />} />

          {/* ✅ Route 2: Login 
             If user is already logged in, redirect them to Dashboard (/)
          */}
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

          {/* ✅ Route 3: Dashboard (Protected) 
             If user is NOT logged in, redirect them to /login
          */}
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

          {/* Catch-all: Redirect unknown URLs to Home */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
