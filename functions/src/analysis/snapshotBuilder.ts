import { createHash } from "node:crypto";
import { Timestamp } from "firebase-admin/firestore";
import type { FootballDataClient } from "../fixtures/footballDataClient.js";

interface FixtureRecord {
  fixtureVersion?: unknown;
  competitionId?: unknown;
  competitionName?: unknown;
  kickoffAt?: unknown;
  status?: unknown;
  homeTeam?: unknown;
  awayTeam?: unknown;
}

interface TeamValue { id: number; name: string }
interface MatchValue {
  id?: number;
  utcDate?: string;
  status?: string;
  homeTeam?: { id?: number; name?: string };
  awayTeam?: { id?: number; name?: string };
  score?: { fullTime?: { home?: number | null; away?: number | null } };
}
interface MatchList { matches?: MatchValue[] }
interface StandingTable {
  standings?: Array<{ type?: string; table?: Array<Record<string, unknown> & { team?: { id?: number } }> }>;
}

export interface AnalysisSnapshot {
  snapshotId: string;
  snapshotVersion: number;
  fixture: {
    fixtureKey: string;
    fixtureVersion: number;
    kickoffAt: string;
    status: string;
    competitionId: string;
    homeTeamId: string;
    awayTeamId: string;
    homeTeamName: string;
    awayTeamName: string;
  };
  dataSnapshotAt: string;
  sections: Record<string, { status: "available" | "unavailable"; observedAt: string | null; data: unknown }>;
  provenance: Array<{ sourceId: string; retrievedAt: string }>;
  contentHash: string;
}

export interface FixtureInsights {
  fixtureKey: string;
  dataSnapshotAt: string;
  recentForm: {
    home: Record<string, unknown>;
    away: Record<string, unknown>;
  } | null;
  headToHead: Array<Record<string, unknown>>;
  standings: {
    home: Record<string, unknown>;
    away: Record<string, unknown>;
  } | null;
  unavailableSections: string[];
}

export function fixtureInsights(snapshot: AnalysisSnapshot): FixtureInsights {
  const recentForm = availableObject(snapshot.sections.recentForm?.status, snapshot.sections.recentForm?.data);
  const standings = availableObject(snapshot.sections.standings?.status, snapshot.sections.standings?.data);
  const headToHead = snapshot.sections.headToHead?.status === "available" && Array.isArray(snapshot.sections.headToHead.data)
    ? snapshot.sections.headToHead.data.filter(isRecord)
    : [];
  return {
    fixtureKey: snapshot.fixture.fixtureKey,
    dataSnapshotAt: snapshot.dataSnapshotAt,
    recentForm: recentForm && isRecord(recentForm.home) && isRecord(recentForm.away)
      ? { home: recentForm.home, away: recentForm.away }
      : null,
    headToHead,
    standings: standings && isRecord(standings.home) && isRecord(standings.away)
      ? { home: standings.home, away: standings.away }
      : null,
    unavailableSections: Object.entries(snapshot.sections)
      .filter(([, section]) => section.status !== "available")
      .map(([key]) => key),
  };
}

export async function buildAnalysisSnapshot(
  fixtureKey: string,
  fixture: FixtureRecord,
  client: FootballDataClient,
  now = new Date(),
): Promise<AnalysisSnapshot> {
  const home = team(fixture.homeTeam);
  const away = team(fixture.awayTeam);
  const kickoffAt = timestampDate(fixture.kickoffAt);
  const competitionId = requiredString(fixture.competitionId, "COMPETITION_UNAVAILABLE");
  const from = new Date(Math.min(now.getTime(), kickoffAt.getTime()) - 180 * 86_400_000);
  const dateFrom = apiDate(from);
  const dateTo = apiDate(new Date(Math.min(now.getTime(), kickoffAt.getTime())));

  const [homeMatchesResult, awayMatchesResult, standingsResult] = await Promise.allSettled([
    client.getTeamMatches<MatchList>(home.id, { dateFrom, dateTo, status: "FINISHED", limit: "12" }),
    client.getTeamMatches<MatchList>(away.id, { dateFrom, dateTo, status: "FINISHED", limit: "12" }),
    client.getCompetitionStandings<StandingTable>(competitionId),
  ]);

  const homeMatches = homeMatchesResult.status === "fulfilled" ? homeMatchesResult.value.data.matches ?? [] : [];
  const awayMatches = awayMatchesResult.status === "fulfilled" ? awayMatchesResult.value.data.matches ?? [] : [];
  const standings = standingsResult.status === "fulfilled"
    ? standingsResult.value.data.standings?.find((entry) => entry.type === "TOTAL")?.table ?? []
    : [];
  const observedAt = now.toISOString();
  const recentFormAvailable = homeMatches.length > 0 && awayMatches.length > 0;
  const headToHead = uniqueMatches([...homeMatches, ...awayMatches])
    .filter((match) => teamPair(match, home.id, away.id))
    .slice(-5)
    .map(normalizedMatch);
  const homeStanding = standings.find((entry) => Number(entry.team?.id) === home.id);
  const awayStanding = standings.find((entry) => Number(entry.team?.id) === away.id);

  const base = {
    snapshotVersion: 1,
    fixture: {
      fixtureKey,
      fixtureVersion: positiveInteger(fixture.fixtureVersion, 1),
      kickoffAt: kickoffAt.toISOString(),
      status: String(fixture.status ?? "scheduled"),
      competitionId,
      homeTeamId: String(home.id),
      awayTeamId: String(away.id),
      homeTeamName: home.name,
      awayTeamName: away.name,
    },
    dataSnapshotAt: observedAt,
    sections: {
      recentForm: {
        status: recentFormAvailable ? "available" as const : "unavailable" as const,
        observedAt: recentFormAvailable ? observedAt : null,
        data: recentFormAvailable ? {
          home: summarizeRecent(homeMatches, home.id),
          away: summarizeRecent(awayMatches, away.id),
        } : null,
      },
      headToHead: {
        status: headToHead.length > 0 ? "available" as const : "unavailable" as const,
        observedAt: headToHead.length > 0 ? observedAt : null,
        data: headToHead.length > 0 ? headToHead : null,
      },
      standings: {
        status: homeStanding && awayStanding ? "available" as const : "unavailable" as const,
        observedAt: homeStanding && awayStanding ? observedAt : null,
        data: homeStanding && awayStanding ? {
          home: normalizedStanding(homeStanding),
          away: normalizedStanding(awayStanding),
        } : null,
      },
      squadAvailability: { status: "unavailable" as const, observedAt: null, data: null },
      lineups: { status: "unavailable" as const, observedAt: null, data: null },
      weather: { status: "unavailable" as const, observedAt: null, data: null },
    },
    provenance: [{ sourceId: "football-data.org-v4", retrievedAt: observedAt }],
  };
  const contentHash = createHash("sha256").update(JSON.stringify(base)).digest("hex");
  return { ...base, snapshotId: `snap_${contentHash.slice(0, 32)}`, contentHash };
}

function summarizeRecent(matches: MatchValue[], teamId: number): Record<string, unknown> {
  const values = matches
    .filter((match) => match.status === "FINISHED" && (match.homeTeam?.id === teamId || match.awayTeam?.id === teamId))
    .sort((a, b) => String(a.utcDate).localeCompare(String(b.utcDate)))
    .slice(-5);
  let wins = 0; let draws = 0; let losses = 0; let goalsFor = 0; let goalsAgainst = 0;
  const form: string[] = [];
  for (const match of values) {
    const isHome = match.homeTeam?.id === teamId;
    const scored = Number(isHome ? match.score?.fullTime?.home : match.score?.fullTime?.away);
    const conceded = Number(isHome ? match.score?.fullTime?.away : match.score?.fullTime?.home);
    if (!Number.isFinite(scored) || !Number.isFinite(conceded)) continue;
    goalsFor += scored; goalsAgainst += conceded;
    if (scored > conceded) { wins += 1; form.push("W"); }
    else if (scored === conceded) { draws += 1; form.push("D"); }
    else { losses += 1; form.push("L"); }
  }
  return { matches: values.map(normalizedMatch), wins, draws, losses, goalsFor, goalsAgainst, form };
}

function normalizedMatch(match: MatchValue): Record<string, unknown> {
  return {
    id: match.id ?? null,
    utcDate: match.utcDate ?? null,
    homeTeamId: match.homeTeam?.id ?? null,
    homeTeamName: match.homeTeam?.name ?? null,
    awayTeamId: match.awayTeam?.id ?? null,
    awayTeamName: match.awayTeam?.name ?? null,
    homeGoals: match.score?.fullTime?.home ?? null,
    awayGoals: match.score?.fullTime?.away ?? null,
  };
}

function normalizedStanding(value: Record<string, unknown>): Record<string, unknown> {
  const allowed = ["position", "playedGames", "form", "won", "draw", "lost", "points", "goalsFor", "goalsAgainst", "goalDifference"];
  return Object.fromEntries(allowed.map((key) => [key, value[key] ?? null]));
}

function uniqueMatches(matches: MatchValue[]): MatchValue[] {
  const values = new Map<number | string, MatchValue>();
  for (const match of matches) values.set(match.id ?? `${match.utcDate}:${match.homeTeam?.id}:${match.awayTeam?.id}`, match);
  return [...values.values()].sort((a, b) => String(a.utcDate).localeCompare(String(b.utcDate)));
}

const teamPair = (match: MatchValue, first: number, second: number): boolean =>
  (match.homeTeam?.id === first && match.awayTeam?.id === second)
  || (match.homeTeam?.id === second && match.awayTeam?.id === first);

function team(value: unknown): TeamValue {
  const data = value as Record<string, unknown> | undefined;
  const id = Number(data?.id);
  const name = typeof data?.name === "string" ? data.name : "";
  if (!Number.isSafeInteger(id) || id <= 0 || !name) throw new Error("TEAM_DATA_UNAVAILABLE");
  return { id, name };
}

function timestampDate(value: unknown): Date {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  const date = new Date(String(value));
  if (!Number.isFinite(date.getTime())) throw new Error("KICKOFF_UNAVAILABLE");
  return date;
}

function requiredString(value: unknown, code: string): string {
  if (typeof value !== "string" || !value.trim()) throw new Error(code);
  return value;
}

function positiveInteger(value: unknown, fallback: number): number {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function apiDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function availableObject(
  status: "available" | "unavailable" | undefined,
  value: unknown,
): Record<string, unknown> | null {
  return status === "available" && isRecord(value) ? value : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
