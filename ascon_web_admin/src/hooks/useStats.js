import { useState, useEffect } from "react";
import axios from "axios";

export function useStats(baseUrl, token, refreshTrigger) {
  const [stats, setStats] = useState({
    users: 0,
    events: 0,
    programmes: 0,
    totalRegistrations: 0,
  });

  useEffect(() => {
    if (!token) return;
    axios
      .get(`${baseUrl}/api/admin/stats`, { headers: { "auth-token": token } })
      .then((res) => setStats(res.data))
      .catch((e) => console.error("Stats error:", e));
  }, [baseUrl, token, refreshTrigger]);

  return stats;
}
