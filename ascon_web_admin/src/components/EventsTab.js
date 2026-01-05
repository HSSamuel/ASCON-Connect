import React from "react";

function EventsTab({
  eventsList,
  canEdit,
  editingId,
  eventForm,
  setEventForm,
  handleEventSubmit,
  cancelEditEvent,
  startEditEvent,
  deleteEventClick,
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
            {editingId ? "✏️ Edit Announcement" : "📢 Post Announcement"}
          </h2>

          <form onSubmit={handleEventSubmit}>
            <div style={{ display: "flex", gap: "10px" }}>
              <input
                style={{ flex: 2, padding: "10px", marginBottom: "10px" }}
                placeholder="Event Title"
                value={eventForm.title}
                onChange={(e) =>
                  setEventForm({ ...eventForm, title: e.target.value })
                }
                required
              />
              <select
                style={{ flex: 1, padding: "10px", marginBottom: "10px" }}
                value={eventForm.type}
                onChange={(e) =>
                  setEventForm({ ...eventForm, type: e.target.value })
                }
              >
                <option>News</option>
                <option>Reunion</option>
                <option>Seminar</option>
                <option>Webinar</option>
              </select>
            </div>
            <input
              style={{
                width: "100%",
                padding: "10px",
                marginBottom: "10px",
                boxSizing: "border-box",
              }}
              placeholder="Image URL (e.g. https://imgur.com/...)"
              value={eventForm.image}
              onChange={(e) =>
                setEventForm({ ...eventForm, image: e.target.value })
              }
            />
            <input
              style={{
                width: "100%",
                padding: "10px",
                marginBottom: "10px",
                boxSizing: "border-box",
              }}
              placeholder="Location"
              value={eventForm.location}
              onChange={(e) =>
                setEventForm({ ...eventForm, location: e.target.value })
              }
              required
            />
            <textarea
              style={{
                width: "100%",
                padding: "10px",
                marginBottom: "10px",
                height: "80px",
                boxSizing: "border-box",
              }}
              placeholder="Details..."
              value={eventForm.description}
              onChange={(e) =>
                setEventForm({ ...eventForm, description: e.target.value })
              }
              required
            />

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
                {editingId ? "UPDATE EVENT" : "PUBLISH POST"}
              </button>
              {editingId && (
                <button
                  type="button"
                  onClick={cancelEditEvent}
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

      <div className="table-responsive">
        <table className="admin-table">
          <thead>
            <tr>
              <th>Image</th>
              <th>Date</th>
              <th>Title</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {eventsList.map((event) => (
              <tr key={event._id}>
                <td data-label="Image">
                  <img
                    src={event.image || "https://via.placeholder.com/50"}
                    alt="banner"
                    style={{
                      width: "50px",
                      height: "30px",
                      objectFit: "cover",
                      borderRadius: "4px",
                    }}
                  />
                </td>
                <td
                  data-label="Date"
                  style={{ fontSize: "13px", color: "#555" }}
                >
                  {new Date(event.date).toLocaleDateString()}
                </td>
                <td data-label="Title">
                  <div style={{ fontWeight: "bold" }}>{event.title}</div>
                  <span className="tag">{event.type}</span>
                </td>
                <td data-label="Action">
                  {canEdit ? (
                    <div className="action-buttons-container">
                      <button
                        onClick={() => startEditEvent(event)}
                        className="approve-btn compact-btn"
                        style={{ backgroundColor: "#3498db" }}
                      >
                        EDIT
                      </button>
                      <button
                        className="delete-btn compact-btn"
                        onClick={() => deleteEventClick(event._id)}
                      >
                        DELETE
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

export default EventsTab;
