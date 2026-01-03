import { useState, useEffect } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import axios from "axios";
// CSS is now loaded globally from App.css

export default function ResetPassword() {
  const [token, setToken] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  // Hook to get the URL parameters
  const useQuery = () => {
    return new URLSearchParams(useLocation().search);
  };

  const query = useQuery();
  const navigate = useNavigate();

  useEffect(() => {
    // Extract token from URL (e.g., ?token=abc123...)
    const tokenParam = query.get("token");
    if (tokenParam) {
      setToken(tokenParam);
    } else {
      setError(true);
      setMessage("Invalid or missing reset token.");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      setError(true);
      setMessage("Passwords do not match!");
      return;
    }

    if (newPassword.length < 6) {
      setError(true);
      setMessage("Password must be at least 6 characters.");
      return;
    }

    setIsLoading(true);
    try {
      // ⚠️ ENSURE THIS MATCHES YOUR LIVE BACKEND URL
      const API_URL = "https://ascon.onrender.com/api/auth/reset-password";

      await axios.post(API_URL, {
        token: token,
        newPassword: newPassword,
      });

      setError(false);
      setMessage("Success! Redirecting to login...");

      // Redirect after 2 seconds
      setTimeout(() => {
        navigate("/login");
      }, 2000);
    } catch (err) {
      setError(true);
      setMessage(err.response?.data?.message || "Something went wrong.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="reset-container">
      <div className="reset-card">
        <h2 className="reset-title">Reset Password</h2>
        <p className="reset-subtitle">Enter your new password below.</p>

        {message && (
          <div
            className={error ? "reset-error-banner" : "reset-success-banner"}
          >
            {message}
          </div>
        )}

        {!token ? (
          <p style={{ color: "red" }}>Error: No token found in URL.</p>
        ) : (
          <form onSubmit={handleSubmit} className="reset-form">
            <input
              type="password"
              placeholder="New Password"
              className="reset-input"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              required
            />
            <input
              type="password"
              placeholder="Confirm Password"
              className="reset-input"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              required
            />
            <button type="submit" className="reset-button" disabled={isLoading}>
              {isLoading ? "Updating..." : "Update Password"}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
