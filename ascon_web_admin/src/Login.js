import React, { useState } from "react";
import axios from "axios";
import { GoogleLogin } from "@react-oauth/google";
import { jwtDecode } from "jwt-decode";
import "./App.css";
import logo from "./assets/logo.png";

// ✅ USE ENV VARIABLE (Standardized)
const BASE_URL = process.env.REACT_APP_API_URL || "http://localhost:5000";

function Login({ onLogin }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  // --- STANDARD EMAIL LOGIN ---
  const handleLogin = async (e) => {
    e.preventDefault();
    setError("");
    setIsLoading(true);

    try {
      const res = await axios.post(`${BASE_URL}/api/auth/login`, {
        email,
        password,
      });
      processLogin(res.data.token);
    } catch (err) {
      setError(err.response?.data?.message || "Login failed.");
    } finally {
      setIsLoading(false);
    }
  };

  // --- GOOGLE LOGIN ---
  const handleGoogleSuccess = async (credentialResponse) => {
    setError("");
    setIsLoading(true);

    try {
      // 1. Send Google Token to Backend
      const res = await axios.post(`${BASE_URL}/api/auth/google`, {
        token: credentialResponse.credential,
      });

      // 2. Process Backend Response
      processLogin(res.data.token);
    } catch (err) {
      if (err.response && err.response.status === 404) {
        setError("Access Denied: You are not a registered Admin.");
      } else {
        setError("Google Login Failed. Try again.");
      }
    } finally {
      setIsLoading(false);
    }
  };

  // --- COMMON LOGIC (VERIFY ADMIN) ---
  const processLogin = (token) => {
    try {
      const decoded = jwtDecode(token);

      // 🔐 SECURITY CHECK: Only Admins Allowed
      if (decoded.isAdmin === true) {
        localStorage.setItem("auth_token", token);
        onLogin(token);
      } else {
        setError("Access Denied: You do not have Admin privileges.");
      }
    } catch (e) {
      setError("Invalid Token received.");
    }
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <img src={logo} alt="ASCON Logo" className="login-logo" />
        <h2 className="login-title">Admin Portal</h2>

        {error && <div className="login-error">{error}</div>}

        <form onSubmit={handleLogin}>
          <div className="form-group">
            <label>Email Address</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              placeholder="Enter admin email"
            />
          </div>

          <div className="form-group">
            <label>Password</label>
            <div className="password-wrapper">
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                placeholder="Enter password"
              />
              <button
                type="button"
                className="password-toggle-btn"
                onClick={() => setShowPassword(!showPassword)}
              >
                {showPassword ? "🙈" : "👁️"}
              </button>
            </div>
          </div>

          <button
            type="submit"
            className="approve-btn login-btn"
            disabled={isLoading}
          >
            {isLoading ? "Logging in..." : "LOGIN"}
          </button>
        </form>

        <div
          style={{ display: "flex", alignItems: "center", margin: "20px 0" }}
        >
          <div
            style={{ flex: 1, height: "1px", backgroundColor: "#ddd" }}
          ></div>
          <span style={{ padding: "0 10px", color: "#888", fontSize: "12px" }}>
            OR
          </span>
          <div
            style={{ flex: 1, height: "1px", backgroundColor: "#ddd" }}
          ></div>
        </div>

        <div style={{ display: "flex", justifyContent: "center" }}>
          <GoogleLogin
            onSuccess={handleGoogleSuccess}
            onError={() => setError("Google Login Failed")}
            theme="outline"
            size="large"
            width="320"
          />
        </div>
      </div>
    </div>
  );
}

export default Login;
