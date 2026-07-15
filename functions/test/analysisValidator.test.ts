import assert from "node:assert/strict";
import test from "node:test";
import { AnalysisResultValidator, type ExpectedAnalysisIdentity, type ValidationSnapshot } from "../src/analysis/validator.js";

const expected: ExpectedAnalysisIdentity = {
  schemaVersion: "2.0", fixtureKey: "provider:2026:1", fixtureVersion: 4,
  snapshotId: "snap_1", snapshotVersion: 7, promptVersion: "football-v2.1.0", modelVersion: "gemini-flash-default",
};
const snapshot: ValidationSnapshot = {
  snapshotId: "snap_1", snapshotVersion: 7,
  fixture: { fixtureKey: "provider:2026:1", fixtureVersion: 4, kickoffAt: "2026-08-12T19:00:00Z" },
  sections: { recentForm: { status: "available" }, lineups: { status: "unavailable" } },
};
const valid = {
  schemaVersion: "2.0", analysisId: "ana_1", status: "ready", fixtureKey: "provider:2026:1", fixtureVersion: 4,
  snapshotId: "snap_1", snapshotVersion: 7, generatedAt: "2026-08-12T12:00:00Z", validUntil: "2026-08-12T18:00:00Z",
  promptVersion: "football-v2.1.0", modelVersion: "gemini-flash-default", language: "en",
  markets: {
    matchResult: { homePct: 46, drawPct: 29, awayPct: 25 }, goals25: { overPct: 54, underPct: 46 },
    bothTeamsScore: { yesPct: 57, noPct: 43 }, likelyScores: [{ home: 1, away: 1, pct: 12 }],
    likelyScoresTotalPct: 12, otherScoresPct: 88,
  },
  confidence: { level: "medium", scorePct: 63 },
  rationale: [{ code: "RECENT_FORM", text: "Available recent form supports a balanced distribution.", evidenceRefs: ["sections.recentForm"] }],
  dataAvailability: { recentForm: "available", lineups: "unavailable" }, limitations: ["LINEUPS_UNAVAILABLE"], moderationStatus: "passed",
};

test("valid evidence-bounded analysis passes", () => {
  assert.equal(new AnalysisResultValidator().validate(valid, snapshot, expected).ok, true);
});

test("invalid totals fail closed", () => {
  const candidate = structuredClone(valid); candidate.markets.matchResult.homePct = 45;
  const result = new AnalysisResultValidator().validate(candidate, snapshot, expected);
  assert.equal(result.ok, false);
  if (!result.ok) assert(result.issues.some((issue) => issue.code === "PROBABILITY_TOTAL_INVALID"));
});

test("unavailable evidence and betting certainty are rejected", () => {
  const candidate = structuredClone(valid);
  candidate.rationale = [{ code: "LINEUP", text: "This is a guaranteed result; bet now.", evidenceRefs: ["sections.lineups"] }];
  const result = new AnalysisResultValidator().validate(candidate, snapshot, expected);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert(result.issues.some((issue) => issue.code === "EVIDENCE_UNAVAILABLE"));
    assert(result.issues.some((issue) => issue.code === "PROHIBITED_CLAIM"));
  }
});

test("identity mismatch and post-kickoff validity are rejected", () => {
  const candidate = structuredClone(valid); candidate.snapshotVersion = 8; candidate.validUntil = "2026-08-12T20:00:00Z";
  const result = new AnalysisResultValidator().validate(candidate, snapshot, expected);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert(result.issues.some((issue) => issue.code === "IDENTITY_MISMATCH"));
    assert(result.issues.some((issue) => issue.code === "TEMPORAL_INVALID"));
  }
});
