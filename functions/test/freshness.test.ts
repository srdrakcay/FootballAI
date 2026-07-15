import assert from "node:assert/strict";
import test from "node:test";
import { applyFreshnessPolicy, promptSnapshotProjection } from "../src/fixtures/freshness.js";

const now = new Date("2026-07-15T12:00:00Z");
const snapshot = {
  dataSnapshotAt: "2026-07-15T11:59:00Z",
  sections: {
    recentForm: { status: "available" as const, observedAt: "2026-07-15T11:30:00Z", data: { matches: 5 } },
    lineups: { status: "available" as const, observedAt: "2026-07-15T09:00:00Z", data: { confirmed: false } },
    weather: { status: "unavailable" as const, observedAt: null, data: null },
  },
};

test("expired available section is normalized to stale", () => {
  const result = applyFreshnessPolicy(snapshot, { maximumAgeSeconds: { recentForm: 3_600, lineups: 1_800 }, minimumAvailableSections: 1 }, now);
  assert.equal(result.eligible, true);
  assert.equal(result.sections.lineups?.status, "stale");
  assert.deepEqual(result.staleSectionNames, ["lineups"]);
});

test("prompt projection excludes stale and unavailable data", () => {
  const result = applyFreshnessPolicy(snapshot, { maximumAgeSeconds: { recentForm: 3_600, lineups: 1_800 }, minimumAvailableSections: 1 }, now);
  const projection = promptSnapshotProjection(snapshot, result);
  assert.deepEqual(Object.keys(projection.sections), ["recentForm"]);
});

test("insufficient available data fails closed", () => {
  const result = applyFreshnessPolicy(snapshot, { maximumAgeSeconds: { recentForm: 60, lineups: 60 }, minimumAvailableSections: 1 }, now);
  assert.equal(result.eligible, false);
});
