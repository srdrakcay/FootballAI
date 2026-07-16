import assert from "node:assert/strict";
import test from "node:test";
import { Timestamp } from "firebase-admin/firestore";
import { buildAnalysisSnapshot, fixtureInsights } from "../src/analysis/snapshotBuilder.js";
import { FootballDataClient } from "../src/fixtures/footballDataClient.js";

test("snapshot builder derives recent form, head-to-head and standings", async () => {
  const matches = [
    match(1, "2026-06-01T12:00:00Z", 10, 20, 2, 1),
    match(2, "2026-06-08T12:00:00Z", 30, 10, 0, 0),
    match(3, "2026-06-15T12:00:00Z", 20, 40, 1, 3),
  ];
  const client = new FootballDataClient({
    token: "token",
    maximumAttempts: 1,
    fetch: async (input) => {
      const url = new URL(String(input));
      if (url.pathname.includes("/standings")) {
        return json({
          standings: [{
            type: "TOTAL",
            table: [
              { position: 2, team: { id: 10 }, playedGames: 10, won: 6, draw: 2, lost: 2, points: 20, goalsFor: 18, goalsAgainst: 10, goalDifference: 8 },
              { position: 6, team: { id: 20 }, playedGames: 10, won: 4, draw: 2, lost: 4, points: 14, goalsFor: 12, goalsAgainst: 14, goalDifference: -2 },
            ],
          }],
        });
      }
      return json({ matches });
    },
  });

  const snapshot = await buildAnalysisSnapshot("football-data:99", {
    fixtureVersion: 1,
    competitionId: "PL",
    kickoffAt: Timestamp.fromDate(new Date("2026-07-20T18:00:00Z")),
    status: "scheduled",
    homeTeam: { id: "10", name: "Home" },
    awayTeam: { id: "20", name: "Away" },
  }, client, new Date("2026-07-16T12:00:00Z"));

  assert.equal(snapshot.sections.recentForm?.status, "available");
  assert.equal(snapshot.sections.headToHead?.status, "available");
  assert.equal(snapshot.sections.standings?.status, "available");
  assert.equal(snapshot.sections.lineups?.status, "unavailable");
  assert.match(snapshot.snapshotId, /^snap_[a-f0-9]{32}$/);
  assert.equal(snapshot.contentHash.length, 64);

  const insights = fixtureInsights(snapshot);
  assert.equal(insights.fixtureKey, "football-data:99");
  assert.equal(insights.recentForm?.home.wins, 1);
  assert.equal(insights.standings?.home.position, 2);
  assert.equal(insights.headToHead.length, 1);
  assert.deepEqual(insights.unavailableSections, ["squadAvailability", "lineups", "weather"]);
});

function match(id: number, utcDate: string, home: number, away: number, homeGoals: number, awayGoals: number) {
  return {
    id,
    utcDate,
    status: "FINISHED",
    homeTeam: { id: home, name: `Team ${home}` },
    awayTeam: { id: away, name: `Team ${away}` },
    score: { fullTime: { home: homeGoals, away: awayGoals } },
  };
}

function json(value: unknown): Response {
  return new Response(JSON.stringify(value), { status: 200, headers: { "content-type": "application/json" } });
}
