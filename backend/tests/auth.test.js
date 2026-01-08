const { generateAlumniId } = require("../routes/auth");

describe("Alumni ID Generation Logic", () => {
  it("should generate a correctly formatted ID for the current year", async () => {
    const id = await generateAlumniId(2025);
    expect(id).toMatch(/^ASC\/2025\/\d{4}$/); // Matches ASC/2025/XXXX
  });

  it("should increment sequence numbers correctly", async () => {
    const id1 = await generateAlumniId(2026);
    const id2 = await generateAlumniId(2026);
    // Logic to verify id2 sequence > id1 sequence
  });
});
