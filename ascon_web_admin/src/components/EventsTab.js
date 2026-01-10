import React from "react"; // ✅ FIXED: Removed unused useEffect, useRef

function EventsTab({
  eventsList,
  canEdit,
  editingId,
  eventForm,
  setEventForm,
  handleEventSubmit,
  startEditEvent,
  cancelEditEvent,
  deleteEventClick,
}) {
  // ✅ SMART RESIZE: Automatically grows the box as you type
  const handleAutoResize = (e) => {
    e.target.style.height = "auto"; // Reset height to recalculate
    e.target.style.height = `${e.target.scrollHeight}px`; // Set to content height
  };

  return (
    <div>
      {/* FORM SECTION */}
      {canEdit && (
        <div className="form-card fade-in">
          <h3>{editingId ? "Edit Event" : "Post New Event/News"}</h3>
          <form onSubmit={handleEventSubmit}>
            <div className="form-grid">
              <input
                type="text"
                placeholder="Title"
                value={eventForm.title}
                onChange={(e) =>
                  setEventForm({ ...eventForm, title: e.target.value })
                }
                required
              />

              <select
                value={eventForm.type}
                onChange={(e) =>
                  setEventForm({ ...eventForm, type: e.target.value })
                }
              >
                <option value="News">News</option>
                <option value="Reunion">Reunion</option>
                <option value="Webinar">Webinar</option>
                <option value="Conference">Conference</option>
                <option value="Workshop">Workshop</option>
                <option value="Symposium">Symposium</option>
                <option value="AGM">AGM (General Assembly)</option>
                <option value="Induction">Induction</option>
                <option value="Event">General Event</option>
              </select>

              <input
                type="text"
                placeholder="Image URL (Optional)"
                value={eventForm.image}
                onChange={(e) =>
                  setEventForm({ ...eventForm, image: e.target.value })
                }
              />
            </div>

            {/* ✅ UPDATED TEXTAREA: Auto-Expanding */}
            <textarea
              placeholder="Description (Type to expand)..."
              rows="3"
              value={eventForm.description}
              onInput={handleAutoResize} // Trigger resize on typing
              onChange={(e) => {
                handleAutoResize(e); // Ensure it resizes on paste/change
                setEventForm({ ...eventForm, description: e.target.value });
              }}
              style={{
                minHeight: "80px",
                resize: "vertical", // Keep manual resize for desktop
                overflow: "hidden", // Hide scrollbar for cleaner look
              }}
              required
            ></textarea>

            <div className="form-actions">
              <button type="submit" className="approve-btn">
                {editingId ? "Update" : "Publish"}
              </button>
              {editingId && (
                <button
                  type="button"
                  onClick={cancelEditEvent}
                  className="delete-btn"
                >
                  Cancel
                </button>
              )}
            </div>
          </form>
        </div>
      )}

      {/* TABLE SECTION */}
      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Type</th>
              <th>Title</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {eventsList.map((evt) => (
              <tr key={evt._id}>
                <td>{new Date(evt.date).toLocaleDateString()}</td>
                <td>
                  <span
                    className={`tag ${evt.type
                      .toLowerCase()
                      .replace(/\s/g, "-")}`}
                  >
                    {evt.type}
                  </span>
                </td>
                <td>{evt.title}</td>
                <td>
                  {canEdit && (
                    <div className="action-buttons-container">
                      <button
                        onClick={() => startEditEvent(evt)}
                        className="approve-btn compact-btn"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => deleteEventClick(evt._id)}
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

export default EventsTab;
