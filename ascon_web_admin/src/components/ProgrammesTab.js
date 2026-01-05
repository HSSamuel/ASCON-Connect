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
          }}
        >
          <h2
            style={{ color: editingId ? "#d4af37" : "#1B5E3A", marginTop: 0 }}
          >
            {editingId ? "✏️ Edit Programme" : "🎓 Add New Programme"}
          </h2>
          <form
            onSubmit={handleProgrammeSubmit}
            style={{ display: "flex", gap: "10px" }}
          >
            <input
              style={{ flex: 3, padding: "10px" }}
              placeholder="Programme Title"
              value={progForm.title}
              onChange={(e) =>
                setProgForm({ ...progForm, title: e.target.value })
              }
              required
            />
            <input
              style={{ flex: 1, padding: "10px" }}
              placeholder="Code"
              value={progForm.code}
              onChange={(e) =>
                setProgForm({ ...progForm, code: e.target.value })
              }
            />
            <button
              type="submit"
              className="approve-btn"
              style={{
                backgroundColor: editingId ? "#d4af37" : "#1B5E3A",
              }}
            >
              {editingId ? "UPDATE" : "ADD"}
            </button>

            {editingId && (
              <button
                type="button"
                onClick={cancelEditProgramme}
                className="delete-btn"
                style={{ backgroundColor: "#666" }}
              >
                CANCEL
              </button>
            )}
          </form>
        </div>
      ) : (
        <div className="empty-state">🔒 View-Only Mode enabled.</div>
      )}

      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Title</th>
              <th>Code</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {programmesList.map((prog) => (
              <tr key={prog._id}>
                <td data-label="Title">
                  <strong>{prog.title}</strong>
                </td>
                <td data-label="Code">{prog.code || "-"}</td>
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
