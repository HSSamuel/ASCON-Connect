import { useState, useEffect, useCallback } from "react";
import axios from "axios";

export function usePaginatedFetch(url, token, trigger = 0) {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [search, setSearch] = useState("");

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const res = await axios.get(url, {
        headers: { "auth-token": token },
        params: {
          page,
          limit: 20,
          search: search || "",
        },
      });

      const responseBody = res.data;

      // ✅ FIX: Added logic to detect 'registrations' key
      if (responseBody.programmes) {
        setData(responseBody.programmes);
        setTotalPages(responseBody.pages);
      } else if (responseBody.users) {
        setData(responseBody.users);
        setTotalPages(responseBody.pages);
      } else if (responseBody.events) {
        setData(responseBody.events);
        setTotalPages(responseBody.pages);
      } else if (responseBody.registrations) {
        setData(responseBody.registrations); // <--- This fixes your Registration Table!
        setTotalPages(responseBody.pages);
      } else if (responseBody.data) {
        setData(Array.isArray(responseBody.data) ? responseBody.data : []);
        setTotalPages(responseBody.pages || 1);
      } else {
        setData([]);
      }
    } catch (err) {
      console.error("Fetch Error:", err);
      setData([]);
    } finally {
      setLoading(false);
    }
  }, [url, token, page, search]);

  // ✅ FIX: Added trigger so the table refreshes when you delete something
  useEffect(() => {
    const timeoutId = setTimeout(() => {
      fetchData();
    }, 500);

    return () => clearTimeout(timeoutId);
  }, [fetchData, trigger]);

  return {
    data,
    loading,
    page,
    setPage,
    totalPages,
    search,
    setSearch,
    refresh: fetchData,
  };
}
