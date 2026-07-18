const test = require("node:test");
const assert = require("node:assert/strict");

const { _test: slip } = require("../server");

test("accepts a slip image when OCR could not read any text", () => {
  assert.equal(
    slip.hasSlipAnalyzeInput({ rawText: "", imageBase64: "encoded" }, ["other"]),
    true,
  );
});

test("rejects an empty slip request and unsupported image MIME types", () => {
  assert.equal(slip.hasSlipAnalyzeInput({ rawText: "" }, ["other"]), false);
  assert.equal(slip.safeImageMimeType("text/plain"), "image/jpeg");
  assert.equal(slip.safeImageMimeType("image/png"), "image/png");
});
