import assert from "node:assert/strict";
import test from "node:test";
import { analysisVersionId } from "../src/analysis/version.js";

const base = {
  fixtureKey: "provider:2026:1", fixtureVersion: 1, snapshotVersion: 1,
  contentHash: "a".repeat(64), schemaVersion: "2.0",
  promptVersion: "football-v2.1.0", modelVersion: "gemini-flash-default",
};

test("version identity changes with snapshot content", () => {
  assert.notEqual(analysisVersionId(base), analysisVersionId({ ...base, contentHash: "b".repeat(64) }));
});

test("locale is not part of canonical version identity", () => {
  assert.equal(analysisVersionId(base), analysisVersionId({ ...base }));
});
