import { useState, useEffect, useCallback } from "react";
import axios from "axios";

export function usePaginatedFetch(url, token, triggerRefresh) {
  const [data, setData] = useState([]);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalItems, setTotalItems] = useState(0);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState("");

  const fetchData = useCallback(async () => {
    if (!url || !token) return;

    setLoading(true);
    try {
      const res = await axios.get(url, {
        headers: { "auth-token": token },
        params: { page, limit: 20, search },
      });

      // Handle different response structures gracefully
      const result = res.data;

      // If backend returns { users: [...], totalPages: 5 }
      // We dynamically find the array in the response
      const arrayKey = Object.keys(result).find((key) =>
        Array.isArray(result[key])
      );

      setData(result[arrayKey] || []);
      setTotalPages(result.pages || 1);
      setTotalItems(result.total || 0);
    } catch (err) {
      console.error(`Error fetching ${url}:`, err);
    } finally {
      setLoading(false);
    }
  }, [url, token, page, search]); // ✅ FIXED: Removed triggerRefresh from here

  useEffect(() => {
    fetchData();
  }, [fetchData, triggerRefresh]); // ✅ FIXED: Added triggerRefresh here

  return {
    data,
    loading,
    page,
    setPage,
    totalPages,
    totalItems,
    search,
    setSearch,
    refresh: fetchData,
  };
}
