import assert from "node:assert/strict";
import test from "node:test";
import { validateRuntimeConfiguration } from "../src/config/validator.js";

test("configuration values are clamped", () => {
  const config = validateRuntimeConfiguration({ free_monthly_unique_views: 999, analysis_lock_lease_seconds: 1 });
  assert.equal(config.freeMonthlyUniqueViews, 20);
  assert.equal(config.analysisLockLeaseSeconds, 30);
  assert.equal(config.featureAnalysisGenerationEnabled, false);
});

test("unknown model alias fails closed", () => {
  assert.throws(() => validateRuntimeConfiguration({ analysis_model_alias: "client-chosen-model" }));
});
