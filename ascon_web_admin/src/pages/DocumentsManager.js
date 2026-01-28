import React, { useState, useEffect, useCallback } from "react";
import api from "../api";
import { useAuth } from "../hooks/useAuth"; // Keep useAuth if you need token/role internally
import DocumentsTab from "../components/DocumentsTab"; // ✅ IMPORT THE TAB COMPONENT
import Toast from "../Toast";

// ✅ Accept props passed from AdminDashboard (specifically canEdit)
const DocumentsManager = ({ canEdit }) => {
  const { token } = useAuth();
  const [docs, setDocs] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  // Search state is lifted here but passed to Tab
  const [search, setSearch] = useState("");
  const [toast, setToast] = useState(null);

  const showToast = (message, type = "success") => {
    setToast({ message, type });
  };

  const fetchDocs = useCallback(async () => {
    try {
      // ✅ Use the API method you created in api.js
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

  // ✅ HANDLER: Passed down to DocumentsTab
  const handleStatusUpdate = async (doc, newStatus) => {
    if (!window.confirm(`Mark request as ${newStatus}? User will be notified.`))
      return;

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

      // Update local state instantly
      setDocs(docs.map((d) => (d._id === doc._id ? updatedDoc : d)));
      showToast(`Request updated to ${newStatus}`, "success");
    } catch (err) {
      showToast("Update failed", "error");
    }
  };

  return (
    <div className="manager-container">
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

      {/* ✅ RENDER THE TAB COMPONENT INSTEAD OF HARDCODED TABLE */}
      <DocumentsTab
        documentsList={docs}
        loading={isLoading}
        canEdit={canEdit}
        updateStatus={handleStatusUpdate}
        search={search}
        setSearch={setSearch}
      />
    </div>
  );
};

export default DocumentsManager;
