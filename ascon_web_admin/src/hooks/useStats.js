import { useState, useEffect } from "react";
import axios from "axios";

export function useStats(baseUrl, token, refreshTrigger) {
  const [stats, setStats] = useState({
    users: 0,
    events: 0,
    programmes: 0,
    totalRegistrations: 0,
    jobs: 0,
    facilities: 0, // ✅ Initialize facilities count
  });

  useEffect(() => {
    if (!token) return;

    const fetchAllStats = async () => {
      try {
        const config = { headers: { "auth-token": token } };

        // ✅ Run both fetches in parallel
        const [adminStatsRes, jobsRes] = await Promise.all([
          axios.get(`${baseUrl}/api/admin/stats`, config),
          axios.get(`${baseUrl}/api/jobs`, config),
        ]);

        // ✅ Calculate Job Count safely
        let jobsCount = 0;
        const jobsData = jobsRes.data;

        if (Array.isArray(jobsData)) {
          jobsCount = jobsData.length;
        } else if (jobsData.data && Array.isArray(jobsData.data)) {
          jobsCount = jobsData.data.length;
        } else if (jobsData.count) {
          jobsCount = jobsData.count;
        }

        // ✅ Merge stats (adminStatsRes.data now includes facilities)
        setStats({
          ...adminStatsRes.data,
          jobs: jobsCount,
        });
      } catch (e) {
        console.error("Stats error:", e);
      }
    };

    fetchAllStats();
  }, [baseUrl, token, refreshTrigger]);

  return stats;
}
