import React from "react";

function UsersTab({
  usersList = [],
  canEdit,
  approveUser,
  toggleAdmin,
  toggleEditPermission,
  deleteUserClick,
  page,
  setPage,
  totalPages,
}) {
  // Helper to display profile pictures
  const renderAvatar = (imagePath) => {
    if (!imagePath) return <div className="avatar-placeholder">👤</div>;
    if (imagePath.startsWith("http"))
      return <img src={imagePath} alt="Avatar" className="avatar" />;
    return (
      <img
        src={`data:image/png;base64,${imagePath}`}
        alt="Avatar"
        className="avatar"
      />
    );
  };

  return (
    <div>
      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Photo</th>
              <th>Full Name</th>
              <th>Status</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {usersList.map((user) => (
              <tr key={user._id}>
                <td data-label="Photo">{renderAvatar(user.profilePicture)}</td>
                <td data-label="Full Name">
                  <strong>{user.fullName}</strong>
                  <div style={{ fontSize: "12px", color: "#666" }}>
                    {user.email}
                  </div>
                  <div style={{ marginTop: "5px" }}>
                    {user.isAdmin && (
                      <span
                        className="tag"
                        style={{
                          backgroundColor: "#007bff",
                          color: "white",
                          fontSize: "10px",
                          marginRight: "5px",
                        }}
                      >
                        ADMIN
                      </span>
                    )}
                    {user.canEdit && (
                      <span
                        className="tag"
                        style={{
                          backgroundColor: "#d4af37",
                          color: "white",
                          fontSize: "10px",
                        }}
                      >
                        EDITOR
                      </span>
                    )}
                  </div>
                </td>
                <td data-label="Status">
                  <span
                    className={`status-badge ${
                      user.isVerified ? "verified" : "pending"
                    }`}
                  >
                    {user.isVerified ? "Verified" : "Pending"}
                  </span>
                </td>
                <td data-label="Action">
                  {canEdit ? (
                    <div className="action-buttons-container">
                      {!user.isVerified && (
                        <button
                          onClick={() => approveUser(user._id, user.fullName)}
                          className="approve-btn compact-btn"
                          title="Verify User"
                        >
                          VERIFY
                        </button>
                      )}

                      <button
                        onClick={() => toggleAdmin(user._id)}
                        className="approve-btn compact-btn"
                        style={{
                          backgroundColor: user.isAdmin ? "#444" : "#007bff",
                        }}
                      >
                        {user.isAdmin ? "REVOKE ADMIN" : "MAKE ADMIN"}
                      </button>

                      {user.isAdmin && (
                        <button
                          onClick={() => toggleEditPermission(user._id)}
                          className="approve-btn compact-btn"
                          style={{
                            backgroundColor: user.canEdit ? "#555" : "purple",
                          }}
                        >
                          {user.canEdit ? "REVOKE EDIT" : "GRANT EDIT"}
                        </button>
                      )}

                      <button
                        onClick={() => deleteUserClick(user._id)}
                        className="delete-btn compact-btn"
                      >
                        DELETE
                      </button>
                    </div>
                  ) : (
                    <span style={{ color: "#999", fontSize: "12px" }}>
                      View Only
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* ✅ PAGINATION CONTROLS */}
      {totalPages > 1 && (
        <div
          style={{
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            gap: "20px",
            marginTop: "20px",
            marginBottom: "40px",
          }}
        >
          <button
            className="delete-btn"
            disabled={page === 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            style={{
              backgroundColor: page === 1 ? "#ccc" : "#666",
              cursor: page === 1 ? "not-allowed" : "pointer",
            }}
          >
            Previous
          </button>

          <span style={{ fontWeight: "bold", color: "#333" }}>
            Page {page} of {totalPages}
          </span>

          <button
            className="approve-btn"
            disabled={page === totalPages}
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            style={{
              backgroundColor: page === totalPages ? "#ccc" : "#1B5E3A",
              cursor: page === totalPages ? "not-allowed" : "pointer",
            }}
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}

export default UsersTab;
