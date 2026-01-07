import React from "react";

function ProgrammesTab({
  programmesList,
  canEdit,
  editingId,
  progForm,
  setProgForm,
  handleProgrammeSubmit,
  cancelEditProgramme,
  startEditProgramme,
  deleteProgrammeClick,
}) {
  return (
    <div>
      {canEdit ? (
        <div
          className="empty-state"
          style={{
            textAlign: "left",
            marginBottom: "30px",
            backgroundColor: "white",
            border: "1px solid #ddd",
            padding: "20px",
            borderRadius: "8px",
          }}
        >
          <h2
            style={{ color: editingId ? "#d4af37" : "#1B5E3A", marginTop: 0 }}
          >
            {editingId ? "✏️ Edit Programme" : "🎓 Add New Programme"}
          </h2>

          <form onSubmit={handleProgrammeSubmit}>
            {/* ROW 1: Title & Code */}
            <div style={{ display: "flex", gap: "10px", marginBottom: "15px" }}>
              <div style={{ flex: 3 }}>
                <label
                  style={{
                    display: "block",
                    fontSize: "12px",
                    color: "#666",
                    marginBottom: "5px",
                  }}
                >
                  Programme Title *
                </label>
                <input
                  style={{
                    width: "100%",
                    padding: "10px",
                    boxSizing: "border-box",
                  }}
                  placeholder="e.g. Regular Course"
                  value={progForm.title}
                  onChange={(e) =>
                    setProgForm({ ...progForm, title: e.target.value })
                  }
                  required
                />
              </div>
              <div style={{ flex: 1 }}>
                <label
                  style={{
                    display: "block",
                    fontSize: "12px",
                    color: "#666",
                    marginBottom: "5px",
                  }}
                >
                  Code
                </label>
                <input
                  style={{
                    width: "100%",
                    padding: "10px",
                    boxSizing: "border-box",
                  }}
                  placeholder="e.g. RC"
                  value={progForm.code}
                  onChange={(e) =>
                    setProgForm({ ...progForm, code: e.target.value })
                  }
                />
              </div>
            </div>

            {/* ✅ NEW ROW: Image URL */}
            <div style={{ marginBottom: "15px" }}>
              <label
                style={{
                  display: "block",
                  fontSize: "12px",
                  color: "#666",
                  marginBottom: "5px",
                }}
              >
                Image URL (Optional)
              </label>
              <input
                style={{
                  width: "100%",
                  padding: "10px",
                  boxSizing: "border-box",
                }}
                placeholder="Paste image link here (e.g. https://imgur.com/...)"
                value={progForm.image}
                onChange={(e) =>
                  setProgForm({ ...progForm, image: e.target.value })
                }
              />
            </div>

            {/* ROW 3: Duration & Fee */}
            <div style={{ display: "flex", gap: "10px", marginBottom: "15px" }}>
              <div style={{ flex: 1 }}>
                <label
                  style={{
                    display: "block",
                    fontSize: "12px",
                    color: "#666",
                    marginBottom: "5px",
                  }}
                >
                  Duration
                </label>
                <input
                  style={{
                    width: "100%",
                    padding: "10px",
                    boxSizing: "border-box",
                  }}
                  placeholder="e.g. 6 Weeks"
                  value={progForm.duration}
                  onChange={(e) =>
                    setProgForm({ ...progForm, duration: e.target.value })
                  }
                />
              </div>
              <div style={{ flex: 1 }}>
                <label
                  style={{
                    display: "block",
                    fontSize: "12px",
                    color: "#666",
                    marginBottom: "5px",
                  }}
                >
                  Fee
                </label>
                <input
                  style={{
                    width: "100%",
                    padding: "10px",
                    boxSizing: "border-box",
                  }}
                  placeholder="e.g. ₦50,000"
                  value={progForm.fee}
                  onChange={(e) =>
                    setProgForm({ ...progForm, fee: e.target.value })
                  }
                />
              </div>
            </div>

            {/* ROW 4: Description */}
            <div style={{ marginBottom: "15px" }}>
              <label
                style={{
                  display: "block",
                  fontSize: "12px",
                  color: "#666",
                  marginBottom: "5px",
                }}
              >
                Description
              </label>
              <textarea
                style={{
                  width: "100%",
                  padding: "10px",
                  height: "80px",
                  boxSizing: "border-box",
                  fontFamily: "inherit",
                }}
                placeholder="Brief details..."
                value={progForm.description}
                onChange={(e) =>
                  setProgForm({ ...progForm, description: e.target.value })
                }
              />
            </div>

            {/* BUTTONS */}
            <div style={{ display: "flex", gap: "10px" }}>
              <button
                type="submit"
                className="approve-btn"
                style={{
                  flex: 1,
                  padding: "12px",
                  backgroundColor: editingId ? "#d4af37" : "#1B5E3A",
                }}
              >
                {editingId ? "UPDATE PROGRAMME" : "ADD PROGRAMME"}
              </button>

              {editingId && (
                <button
                  type="button"
                  onClick={cancelEditProgramme}
                  className="delete-btn"
                  style={{ flex: 0.3, backgroundColor: "#666" }}
                >
                  CANCEL
                </button>
              )}
            </div>
          </form>
        </div>
      ) : (
        <div className="empty-state">🔒 View-Only Mode enabled.</div>
      )}

      {/* TABLE */}
      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Image</th>
              <th style={{ width: "30%" }}>Title</th>
              <th>Code</th>
              <th>Info</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {programmesList.map((prog) => (
              <tr key={prog._id}>
                {/* ✅ NEW COLUMN: Image Preview */}
                <td data-label="Image">
                  {prog.image ? (
                    <img
                      src={prog.image}
                      alt="prog"
                      style={{
                        width: "40px",
                        height: "40px",
                        borderRadius: "4px",
                        objectFit: "cover",
                      }}
                    />
                  ) : (
                    <div
                      style={{
                        width: "40px",
                        height: "40px",
                        background: "#eee",
                        borderRadius: "4px",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                      }}
                    >
                      🎓
                    </div>
                  )}
                </td>
                <td data-label="Title">
                  <strong>{prog.title}</strong>
                  {prog.description && (
                    <div
                      style={{
                        fontSize: "12px",
                        color: "#666",
                        marginTop: "4px",
                        maxWidth: "300px",
                        whiteSpace: "nowrap",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                      }}
                    >
                      {prog.description}
                    </div>
                  )}
                </td>
                <td data-label="Code">
                  <span
                    className="tag"
                    style={{ backgroundColor: "#eef2ff", color: "#4f46e5" }}
                  >
                    {prog.code || "-"}
                  </span>
                </td>
                <td data-label="Info">
                  <div style={{ fontSize: "13px" }}>
                    {prog.duration && <div>⏳ {prog.duration}</div>}
                    {prog.fee && (
                      <div style={{ color: "green" }}>💰 {prog.fee}</div>
                    )}
                  </div>
                </td>
                <td data-label="Action">
                  {canEdit ? (
                    <div className="action-buttons-container">
                      <button
                        onClick={() => startEditProgramme(prog)}
                        className="approve-btn compact-btn"
                        style={{ backgroundColor: "#3498db" }}
                      >
                        EDIT
                      </button>

                      <button
                        className="delete-btn compact-btn"
                        onClick={() => deleteProgrammeClick(prog._id)}
                      >
                        REMOVE
                      </button>
                    </div>
                  ) : (
                    <span style={{ color: "#ccc" }}>🔒</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default ProgrammesTab;
