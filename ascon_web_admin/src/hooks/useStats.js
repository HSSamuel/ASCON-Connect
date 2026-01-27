import { useState, useEffect } from "react";
import api from "../api"; // ✅ Import centralized API
export function useStats(refreshTrigger) {
  const [stats, setStats] = useState({
    users: 0,
    events: 0,
    programmes: 0,
    totalRegistrations: 0,
    jobs: 0,
    facilities: 0,
  });

  useEffect(() => {
    const fetchAllStats = async () => {
      try {
        // ✅ Run fetches in parallel using api client
        const [adminStatsRes, jobsRes] = await Promise.all([
          api.get("/api/admin/stats"),
          api.get("/api/jobs"),
        ]);

        let jobsCount = 0;
        const jobsData = jobsRes.data;

        if (Array.isArray(jobsData)) {
          jobsCount = jobsData.length;
        } else if (jobsData.data && Array.isArray(jobsData.data)) {
          jobsCount = jobsData.data.length;
        } else if (jobsData.count) {
          jobsCount = jobsData.count;
        }

        setStats({
          ...adminStatsRes.data,
          jobs: jobsCount,
        });
      } catch (e) {
        console.error("Stats error:", e);
      }
    };

    fetchAllStats();
  }, [refreshTrigger]); // ✅ Only depends on refreshTrigger now

  return stats;
}
