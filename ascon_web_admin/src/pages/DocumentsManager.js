import React, { useState, useEffect, useCallback } from "react";
import api from "../api";
import { useAuth } from "../hooks/useAuth";
import SkeletonTable from "../components/SkeletonTable";
import Toast from "../Toast";

const DocumentsManager = () => {
  const { token } = useAuth();
  const [docs, setDocs] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [processingId, setProcessingId] = useState(null);

  // ✅ 1. ADDED SEARCH STATE
  const [search, setSearch] = useState("");

  const [toast, setToast] = useState(null);

  const showToast = (message, type = "success") => {
    setToast({ message, type });
  };

  const fetchDocs = useCallback(async () => {
    try {
      const data = await api.getDocuments(token);
      setDocs(data);
    } catch (err) {
      console.error(err);
      showToast("Failed to load requests", "error");
    } finally {
      setIsLoading(false);
    }
  }, [token]);

  useEffect(() => {
    fetchDocs();
  }, [fetchDocs]);

  // ✅ 2. CLIENT-SIDE FILTERING
  const filteredDocs = docs.filter(
    (doc) =>
      (doc.user?.fullName || "").toLowerCase().includes(search.toLowerCase()) ||
      (doc.type || "").toLowerCase().includes(search.toLowerCase()) ||
      (doc.status || "").toLowerCase().includes(search.toLowerCase()),
  );

  // ✅ 3. EXPORT TO CSV FUNCTION
  const exportToCSV = () => {
    if (!filteredDocs || filteredDocs.length === 0) {
      alert("No data to export.");
      return;
    }

    const headers = [
      "User Name",
      "Alumni ID",
      "Document Type",
      "Details",
      "Status",
      "Date Requested",
      "Admin Note",
    ];

    const rows = filteredDocs.map((doc) => [
      `"${doc.user?.fullName || "Unknown"}"`,
      `"${doc.user?.alumniId || "N/A"}"`,
      `"${doc.type}"`,
      `"${doc.details}"`,
      doc.status,
      new Date(doc.createdAt).toLocaleDateString(),
      `"${doc.adminComment || ""}"`,
    ]);

    const csvContent = [
      headers.join(","),
      ...rows.map((row) => row.join(",")),
    ].join("\n");

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `ascon_documents_${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleStatusUpdate = async (doc, newStatus) => {
    if (!window.confirm(`Mark request as ${newStatus}? User will be notified.`))
      return;

    setProcessingId(doc._id);
    try {
      const comment = window.prompt(
        "Add a note for the user? (e.g., Tracking Number)",
        doc.adminComment || "",
      );
      const updatedDoc = await api.updateDocumentStatus(
        doc._id,
        newStatus,
        comment,
        token,
      );

      setDocs(docs.map((d) => (d._id === doc._id ? updatedDoc : d)));
      showToast(`Request updated to ${newStatus}`, "success");
    } catch (err) {
      showToast("Update failed", "error");
    } finally {
      setProcessingId(null);
    }
  };

  const getStatusBadge = (status) => {
    const colors = {
      Pending: "bg-yellow-100 text-yellow-800",
      Processing: "bg-blue-100 text-blue-800",
      Ready: "bg-purple-100 text-purple-800",
      Delivered: "bg-green-100 text-green-800",
      Rejected: "bg-red-100 text-red-800",
    };
    return (
      <span
        className={`px-2 py-1 rounded-full text-xs font-semibold ${colors[status] || "bg-gray-100"}`}
      >
        {status}
      </span>
    );
  };

  if (isLoading) return <SkeletonTable />;

  return (
    <div className="p-6 relative">
      <h1 className="text-2xl font-bold mb-6 text-gray-800">
        Document Requests
      </h1>

      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}

      {/* ✅ 4. HEADER: SEARCH & EXPORT UI */}
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginBottom: "15px",
          flexWrap: "wrap",
          gap: "10px",
        }}
      >
        <input
          type="text"
          placeholder="🔍 Search Request, Name, or Status..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{
            maxWidth: "350px",
            padding: "10px",
            border: "1px solid #ccc",
            borderRadius: "6px",
          }}
        />

        <button
          onClick={exportToCSV}
          className="approve-btn"
          style={{
            backgroundColor: "#1B5E3A",
            color: "white",
            padding: "8px 16px",
            borderRadius: "6px",
            border: "none",
            cursor: "pointer",
            display: "flex",
            alignItems: "center",
            gap: "8px",
            fontWeight: "bold",
            fontSize: "14px",
          }}
        >
          📥 Export to Excel
        </button>
      </div>

      <div className="bg-white rounded-lg shadow overflow-hidden">
        <div className="overflow-x-auto">
          {/* ✅ ADDED 'admin-table' CLASS FOR CONSISTENT STYLING */}
          <table className="min-w-full divide-y divide-gray-200 admin-table">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  User
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Request
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Date
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filteredDocs.map((doc) => (
                <tr key={doc._id}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div
                      className="flex items-center"
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: "10px",
                      }}
                    >
                      <div
                        className="avatar-placeholder"
                        style={{
                          width: 32,
                          height: 32,
                          fontSize: "14px",
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          backgroundColor: "#eee",
                          borderRadius: "50%",
                        }}
                      >
                        {(doc.user?.fullName || "U").charAt(0)}
                      </div>
                      <div>
                        <div className="text-sm font-medium text-gray-900">
                          {doc.user?.fullName || "Unknown"}
                        </div>
                        <div
                          className="text-sm text-gray-500"
                          style={{ fontSize: "11px" }}
                        >
                          {doc.user?.alumniId || "No ID"}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="text-sm font-bold text-gray-900">
                      {doc.type}
                    </div>
                    <div
                      className="text-xs text-gray-500 truncate"
                      style={{ maxWidth: "200px" }}
                      title={doc.details}
                    >
                      {doc.details}
                    </div>
                    {doc.adminComment && (
                      <div className="text-xs text-red-500 mt-1">
                        Note: {doc.adminComment}
                      </div>
                    )}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-500">
                      {new Date(doc.createdAt).toLocaleDateString()}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    {getStatusBadge(doc.status)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    {processingId === doc._id ? (
                      <span className="text-gray-400">Updating...</span>
                    ) : (
                      <select
                        className="border border-gray-300 rounded text-sm p-1"
                        style={{ cursor: "pointer" }}
                        value={doc.status}
                        onChange={(e) =>
                          handleStatusUpdate(doc, e.target.value)
                        }
                      >
                        <option value="Pending">Pending</option>
                        <option value="Processing">Processing</option>
                        <option value="Ready">Ready</option>
                        <option value="Delivered">Delivered</option>
                        <option value="Rejected">Rejected</option>
                      </select>
                    )}
                  </td>
                </tr>
              ))}
              {filteredDocs.length === 0 && (
                <tr>
                  <td
                    colSpan="5"
                    className="px-6 py-10 text-center text-gray-500"
                  >
                    No document requests found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default DocumentsManager;
