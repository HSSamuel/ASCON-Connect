import React from "react";

function JobsTab({
  jobsList,
  canEdit,
  editingId,
  jobForm,
  setJobForm,
  handleSubmit,
  startEdit,
  cancelEdit,
  deleteClick,
}) {
  // Auto-expand textarea
  const handleAutoResize = (e) => {
    e.target.style.height = "auto";
    e.target.style.height = `${e.target.scrollHeight}px`;
  };

  return (
    <div>
      {canEdit && (
        <div className="form-card fade-in">
          <h3>
            {editingId ? "✏️ Edit Opportunity" : "💼 Post New Opportunity"}
          </h3>
          <form onSubmit={handleSubmit}>
            <div className="form-grid">
              <input
                placeholder="Job Title *"
                value={jobForm.title}
                onChange={(e) =>
                  setJobForm({ ...jobForm, title: e.target.value })
                }
                required
              />
              <input
                placeholder="Company *"
                value={jobForm.company}
                onChange={(e) =>
                  setJobForm({ ...jobForm, company: e.target.value })
                }
                required
              />
              <input
                placeholder="Location (e.g. Lagos / Remote)"
                value={jobForm.location}
                onChange={(e) =>
                  setJobForm({ ...jobForm, location: e.target.value })
                }
                required
              />
              <select
                value={jobForm.type}
                onChange={(e) =>
                  setJobForm({ ...jobForm, type: e.target.value })
                }
              >
                <option>Full-time</option>
                <option>Part-time</option>
                <option>Contract</option>
                <option>Internship</option>
                <option>Remote</option>
              </select>
              <input
                placeholder="Salary (Optional)"
                value={jobForm.salary}
                onChange={(e) =>
                  setJobForm({ ...jobForm, salary: e.target.value })
                }
              />
              <input
                placeholder="Apply Link: Google, Microsoft forms, Email etc. *"
                value={jobForm.applicationLink}
                onChange={(e) =>
                  setJobForm({ ...jobForm, applicationLink: e.target.value })
                }
                required
              />
            </div>
            <textarea
              placeholder="Job Description..."
              value={jobForm.description}
              onInput={handleAutoResize}
              onChange={(e) => {
                handleAutoResize(e);
                setJobForm({ ...jobForm, description: e.target.value });
              }}
              style={{
                minHeight: "80px",
                width: "100%",
                padding: "10px",
                marginTop: "10px",
                resize: "vertical",
              }}
              required
            />
            <div className="form-actions">
              <button type="submit" className="approve-btn">
                {editingId ? "Update" : "Post Job"}
              </button>
              {editingId && (
                <button
                  type="button"
                  onClick={cancelEdit}
                  className="delete-btn"
                >
                  Cancel
                </button>
              )}
            </div>
          </form>
        </div>
      )}

      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Role</th>
              <th>Company</th>
              <th>Type</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {jobsList.map((job) => (
              <tr key={job._id}>
                <td>
                  <strong>{job.title}</strong>
                </td>
                <td>{job.company}</td>
                <td>
                  <span className="tag">{job.type}</span>
                </td>
                <td>
                  {canEdit && (
                    <div className="action-buttons-container">
                      <button
                        onClick={() => startEdit(job)}
                        className="approve-btn compact-btn"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => deleteClick(job._id)}
                        className="delete-btn compact-btn"
                      >
                        Delete
                      </button>
                    </div>
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

export default JobsTab;
