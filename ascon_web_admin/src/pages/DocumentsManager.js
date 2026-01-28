import React, { useState, useEffect, useCallback } from "react";
import api from "../api";
import { useAuth } from "../hooks/useAuth";
import SkeletonTable from "../components/SkeletonTable";
import Toast from "../Toast"; // ✅ Using your LOCAL Toast component

const DocumentsManager = () => {
  const { token } = useAuth();
  const [docs, setDocs] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [processingId, setProcessingId] = useState(null);

  // ✅ Local Toast State
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

      <div className="bg-white rounded-lg shadow overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  User
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Details
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
              {docs.map((doc) => (
                <tr key={doc._id}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-gray-900">
                      {doc.user?.fullName || "Unknown"}
                    </div>
                    <div className="text-sm text-gray-500">
                      {doc.user?.alumniId}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900">{doc.type}</div>
                    <div className="text-xs text-gray-500">
                      {new Date(doc.createdAt).toLocaleDateString()}
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <div
                      className="text-sm text-gray-900 max-w-xs truncate"
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
                    {getStatusBadge(doc.status)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    {processingId === doc._id ? (
                      <span className="text-gray-400">Updating...</span>
                    ) : (
                      <select
                        className="border border-gray-300 rounded text-sm p-1"
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
              {docs.length === 0 && (
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
