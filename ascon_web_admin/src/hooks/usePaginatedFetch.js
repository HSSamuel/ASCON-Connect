import { useState, useEffect, useCallback } from "react";
import axios from "axios";

export function usePaginatedFetch(url, token) {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [search, setSearch] = useState(""); // ✅ Manages Search State

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      // ✅ FIX: Ensure search is attached to URL
      const res = await axios.get(url, {
        headers: { "auth-token": token },
        params: {
          page,
          limit: 20,
          search: search || "", // <--- CRITICAL
        },
      });

      // Handle different response structures
      if (res.data.users) {
        setData(res.data.users);
        setTotalPages(res.data.pages);
      } else if (res.data.data) {
        setData(res.data.data);
        setTotalPages(res.data.pages || 1);
      } else {
        setData([]);
      }
    } catch (err) {
      console.error("Fetch Error:", err);
    } finally {
      setLoading(false);
    }
  }, [url, token, page, search]); // ✅ Depend on 'search'

  // ✅ Auto-Fetch when page or search changes
  useEffect(() => {
    // Optional: Add debounce for search to prevent too many requests
    const timeoutId = setTimeout(() => {
      fetchData();
    }, 500); // 500ms delay while typing

    return () => clearTimeout(timeoutId);
  }, [fetchData]);

  return {
    data,
    loading,
    page,
    setPage,
    totalPages,
    search,
    setSearch, // ✅ Pass this back so UI can update it
    refresh: fetchData,
  };
}
