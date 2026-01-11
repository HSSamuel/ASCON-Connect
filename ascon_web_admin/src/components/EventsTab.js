import React from "react"; 

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

              {/* ✅ NEW LOCATION FIELD */}
              <input
                type="text"
                placeholder="Location (e.g. Abuja Hall or Zoom)"
                value={eventForm.location || ""}
                onChange={(e) =>
                  setEventForm({ ...eventForm, location: e.target.value })
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

            {/* ✅ AUTO-EXPANDING TEXTAREA */}
            <textarea
              placeholder="Description (Type to expand)..."
              rows="3"
              value={eventForm.description}
              onInput={handleAutoResize} 
              onChange={(e) => {
                handleAutoResize(e); 
                setEventForm({ ...eventForm, description: e.target.value });
              }}
              style={{
                minHeight: "80px",
                resize: "vertical", 
                overflow: "hidden", 
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
              <th>Location</th> {/* ✅ Show Location in Table too */}
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
                <td>{evt.location || "ASCON Complex"}</td> {/* ✅ Display Location */}
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