import React, { useState, useEffect } from "react";
import AdminDashboard from "./AdminDashboard";
import Login from "./Login";

function App() {
  const [token, setToken] = useState(null);

  // Check for existing session
  useEffect(() => {
    const savedToken = localStorage.getItem("auth_token");
    if (savedToken) {
      setToken(savedToken);
    }
  }, []);

  const handleLogout = () => {
    localStorage.removeItem("auth_token");
    setToken(null);
  };

  return (
    <div className="App">
      {token ? (
        <AdminDashboard token={token} onLogout={handleLogout} />
      ) : (
        <Login onLogin={(newToken) => setToken(newToken)} />
      )}
    </div>
  );
}

export default App;
