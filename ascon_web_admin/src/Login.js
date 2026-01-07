import React, { useState } from "react";
import axios from "axios";
import { GoogleLogin } from "@react-oauth/google";
import { jwtDecode } from "jwt-decode";
import "./App.css";
import logo from "./assets/logo.png";

// Standardized Environment Variable
const BASE_URL = process.env.REACT_APP_API_URL || "https://ascon.onrender.com";

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
      const res = await axios.post(`${BASE_URL}/api/auth/google`, {
        token: credentialResponse.credential,
      });
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

  // --- SECURITY LOGIC (VERIFY ADMIN) ---
  const processLogin = (token) => {
    try {
      const decoded = jwtDecode(token);
      // Security Check: Ensure only Admins can access the dashboard
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
        <h2 className="login-title">ASCON ADMIN</h2>

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
            className="login-btn"
            disabled={isLoading}
            style={{ backgroundColor: "var(--primary)" }} // ✅ Dynamic theme color
          >
            {isLoading ? "AUTHENTICATING..." : "LOGIN"}
          </button>
        </form>

        <div
          style={{ display: "flex", alignItems: "center", margin: "20px 0" }}
        >
          <div
            style={{
              flex: 1,
              height: "1px",
              backgroundColor: "var(--border-color)",
            }}
          ></div>
          <span
            style={{
              padding: "0 10px",
              color: "var(--text-muted)",
              fontSize: "12px",
            }}
          >
            OR
          </span>
          <div
            style={{
              flex: 1,
              height: "1px",
              backgroundColor: "var(--border-color)",
            }}
          ></div>
        </div>

        <div className="google-login-wrapper">
          <GoogleLogin
            onSuccess={handleGoogleSuccess}
            onError={() => setError("Google Login Failed")}
            theme="outline"
            size="large"
            shape="pill" /* ✅ Matches your design better */
            width="100%" /* ✅ Forces it to take container width */
          />
        </div>
      </div>
    </div>
  );
}

export default Login;
