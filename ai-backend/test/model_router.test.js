const test = require("node:test");
const assert = require("node:assert/strict");

const { _test: router } = require("../server");

test("routes fast and deep work to the appropriate stable models", () => {
  assert.equal(router.selectModel("fast", "chat"), "gemini-3.1-flash-lite");
  assert.equal(router.selectModel("deep", "chat"), "gemini-3.5-flash");
  assert.equal(router.selectModel("auto", "analysis"), "gemini-3.5-flash");
});

test("temporarily skips a rate-limited model and restores it after success", () => {
  const preferred = router.GEMINI_MODEL_POOL[0];
  router.markModelSuccess(preferred);
  assert.equal(router.modelCandidates(preferred)[0], preferred);

  router.markModelFailure(preferred, {
    response: { status: 429, headers: {} },
  });
  assert.equal(router.modelCandidates(preferred).includes(preferred), false);

  router.markModelSuccess(preferred);
  assert.equal(router.modelCandidates(preferred)[0], preferred);
});
