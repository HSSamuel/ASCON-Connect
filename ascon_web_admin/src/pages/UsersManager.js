import React, { useState } from "react";
import axios from "axios";
import UsersTab from "../components/UsersTab"; // Reusing your existing UI
import ConfirmModal from "../ConfirmModal";
import Toast from "../Toast";
import { usePaginatedFetch } from "../hooks/usePaginatedFetch";

const BASE_URL = process.env.REACT_APP_API_URL || "https://ascon-st50.onrender.com";

function UsersManager({ token, canEdit }) {
  const [toast, setToast] = useState(null);
  const [deleteModal, setDeleteModal] = useState({ show: false, id: null });

  // ✅ 1. DATA FETCHING (Isolated here)
  // This will only run when the "Users" tab is active!
  const users = usePaginatedFetch(`${BASE_URL}/api/admin/users`, token);

  // --- ACTIONS ---
  const showToast = (message, type = "success") => setToast({ message, type });

  const approveUser = async (id, name) => {
    try {
      await axios.put(
        `${BASE_URL}/api/admin/users/${id}/verify`,
        {},
        { headers: { "auth-token": token } }
      );
      showToast(`${name} verified!`);
      users.refresh(); // Reload list
    } catch (err) {
      showToast("Failed to verify user.", "error");
    }
  };

  const toggleAdmin = async (id) => {
    try {
      await axios.put(
        `${BASE_URL}/api/admin/users/${id}/toggle-admin`,
        {},
        { headers: { "auth-token": token } }
      );
      showToast("Admin status updated");
      users.refresh();
    } catch (err) {
      showToast("Update failed.", "error");
    }
  };

  const toggleEditPermission = async (id) => {
    try {
      await axios.put(
        `${BASE_URL}/api/admin/users/${id}/toggle-edit`,
        {},
        { headers: { "auth-token": token } }
      );
      showToast("Permissions updated");
      users.refresh();
    } catch (err) {
      showToast("Update failed.", "error");
    }
  };

  const handleDelete = async () => {
    try {
      await axios.delete(`${BASE_URL}/api/admin/users/${deleteModal.id}`, {
        headers: { "auth-token": token },
      });
      showToast("User deleted successfully");
      users.refresh();
    } catch (err) {
      showToast("Delete failed", "error");
    }
    setDeleteModal({ show: false, id: null });
  };

  return (
    <div className="manager-container">
      {/* LOCAL TOAST & MODAL */}
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}
      <ConfirmModal
        isOpen={deleteModal.show}
        title="Delete User"
        message="Are you sure? This cannot be undone."
        onClose={() => setDeleteModal({ show: false, id: null })}
        onConfirm={handleDelete}
      />

      {/* REUSED UI COMPONENT */}
      <UsersTab
        usersList={users.data}
        loading={users.loading}
        page={users.page}
        setPage={users.setPage}
        totalPages={users.totalPages}
        search={users.search}
        setSearch={users.setSearch}
        canEdit={canEdit}
        approveUser={approveUser}
        toggleAdmin={toggleAdmin}
        toggleEditPermission={toggleEditPermission}
        deleteUserClick={(id) => setDeleteModal({ show: true, id })}
      />
    </div>
  );
}

export default UsersManager;
