import assert from "node:assert/strict";
import test from "node:test";
import {
  fetchApiFootballDay, fixtureStatus, isUsableApiFootballFixture, normalizeApiFootballFixture, parseLeagueAllowlist, servedDates,
  type ApiFootballFixture,
} from "../src/fixtures/apiFootball.js";

const sample = (overrides: Partial<ApiFootballFixture> = {}): ApiFootballFixture => ({
  fixture: { id: 1234, date: "2026-10-22T16:00:00+00:00", status: { short: "NS" } },
  league: { id: 203, name: "Süper Lig", country: "Turkey" },
  teams: { home: { id: 645, name: "Galatasaray" }, away: { id: 611, name: "Fenerbahce" } },
  ...overrides,
});

test("free plan serves yesterday, today and tomorrow only, clipped to the requested window", () => {
  const now = new Date("2026-10-21T12:00:00Z");
  assert.deepEqual(servedDates("2026-10-19", "2026-10-24", now), ["2026-10-20", "2026-10-21", "2026-10-22"]);
  assert.deepEqual(servedDates("2026-10-22", "2026-10-25", now), ["2026-10-22"]);
  assert.deepEqual(servedDates("2026-10-24", "2026-10-26", now), []);
});

test("fixtures are normalized as browse-only with namespaced team ids and catalog codes", () => {
  const normalized = normalizeApiFootballFixture(sample());
  assert.equal(normalized.analysisAvailable, false);
  assert.equal(normalized.competitionId, "TSL");
  assert.equal(normalized.competitionAreaName, "Turkey");
  assert.deepEqual(normalized.homeTeam, { id: "af:645", name: "Galatasaray" });
  assert.equal(normalized.status, "scheduled");
  assert.equal(normalized.kickoffAt.toISOString(), "2026-10-22T16:00:00.000Z");
});

test("status codes map to the app's statuses", () => {
  assert.equal(fixtureStatus("FT"), "finished");
  assert.equal(fixtureStatus("2H"), "in_progress");
  assert.equal(fixtureStatus("PST"), "postponed");
  assert.equal(fixtureStatus("whatever"), "scheduled");
});

test("only allowlisted leagues with complete data are usable", () => {
  const allowed = new Set([203]);
  assert.equal(isUsableApiFootballFixture(sample(), allowed), true);
  assert.equal(isUsableApiFootballFixture(sample({ league: { id: 39, name: "Premier League" } }), allowed), false);
  assert.equal(isUsableApiFootballFixture(sample({ teams: { home: { name: "A" }, away: {} } }), allowed), false);
});

test("league allowlist accepts JSON, rejects unknown ids and falls back to the catalog", () => {
  assert.deepEqual(parseLeagueAllowlist("[203, 253, 39, 203]"), [203, 253]);
  assert.ok(parseLeagueAllowlist("not json").includes(203));
  assert.ok(parseLeagueAllowlist(undefined).includes(253));
});

test("a plan error in the response body is surfaced, a good body returns fixtures and quota", async () => {
  const ok = await fetchApiFootballDay("key", "2026-10-21", (async () =>
    new Response(JSON.stringify({ errors: [], response: [sample()] }), { status: 200, headers: { "x-ratelimit-requests-remaining": "88" } })) as typeof fetch);
  assert.equal(ok.fixtures.length, 1);
  assert.equal(ok.remainingToday, 88);
  await assert.rejects(
    fetchApiFootballDay("key", "2026-10-25", (async () =>
      new Response(JSON.stringify({ errors: { plan: "Free plans do not have access to this date" }, response: [] }), { status: 200 })) as typeof fetch),
    /API_FOOTBALL_200/,
  );
  await assert.rejects(fetchApiFootballDay("", "2026-10-21"), /API_FOOTBALL_SECRET_UNAVAILABLE/);
});
