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
                <option value="Event">Event</option>
                <option value="Reunion">Reunion</option>
                <option value="Webinar">Webinar</option>
              </select>

              {/* ❌ REMOVED: Location Input used to be here */}

              <input
                type="text"
                placeholder="Image URL (Optional)"
                value={eventForm.image}
                onChange={(e) =>
                  setEventForm({ ...eventForm, image: e.target.value })
                }
              />
            </div>
            <textarea
              placeholder="Description..."
              rows="3"
              value={eventForm.description}
              onChange={(e) =>
                setEventForm({ ...eventForm, description: e.target.value })
              }
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
              {/* ❌ REMOVED: Location Header */}
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {eventsList.map((evt) => (
              <tr key={evt._id}>
                <td>{new Date(evt.date).toLocaleDateString()}</td>
                <td>
                  <span className={`tag ${evt.type.toLowerCase()}`}>
                    {evt.type}
                  </span>
                </td>
                <td>{evt.title}</td>
                {/* ❌ REMOVED: Location Cell */}
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
