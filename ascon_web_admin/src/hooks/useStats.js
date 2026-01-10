import { useState, useEffect } from "react";
import axios from "axios";

export function useStats(baseUrl, token, refreshTrigger) {
  const [stats, setStats] = useState({
    users: 0,
    events: 0,
    programmes: 0,
    totalRegistrations: 0,
    jobs: 0, // ✅ Initialize jobs count
  });

  useEffect(() => {
    if (!token) return;

    const fetchAllStats = async () => {
      try {
        const config = { headers: { "auth-token": token } };

        // ✅ Run both fetches in parallel
        // 1. Get legacy stats (Users, Events, etc.)
        // 2. Get Jobs count directly from the jobs route
        const [adminStatsRes, jobsRes] = await Promise.all([
          axios.get(`${baseUrl}/api/admin/stats`, config),
          axios.get(`${baseUrl}/api/jobs`, config),
        ]);

        // ✅ Calculate Job Count safely (handles Array or Object response)
        let jobsCount = 0;
        const jobsData = jobsRes.data;

        if (Array.isArray(jobsData)) {
          jobsCount = jobsData.length;
        } else if (jobsData.data && Array.isArray(jobsData.data)) {
          jobsCount = jobsData.data.length; // Handles { success: true, data: [...] }
        } else if (jobsData.count) {
          jobsCount = jobsData.count;
        }

        // ✅ Merge them into state
        setStats({
          ...adminStatsRes.data, // Keep existing structure (users, events, etc.)
          jobs: jobsCount, // Add the new number
        });
      } catch (e) {
        console.error("Stats error:", e);
      }
    };

    fetchAllStats();
  }, [baseUrl, token, refreshTrigger]);

  return stats;
}
