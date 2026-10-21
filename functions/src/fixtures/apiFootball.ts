/**
 * Second fixtures provider (API-Football, api-sports.io), LIST-ONLY on the free plan.
 *
 * Free-plan facts verified with a probe on 2026-10-21: `GET /fixtures?date=` works for yesterday..tomorrow
 * only; the `last` parameter (form, head-to-head) and 2026 standings are refused. Fixtures from this
 * provider are therefore browse-only: they carry `analysisAvailable: false` and the backend refuses to
 * start an analysis (and never charges) for them. football-data.org stays the owner of every league it serves.
 */

export interface ApiFootballLeague {
  /** App competition code (client category tables know most of these). */
  readonly code: string;
  readonly name: string;
}

/** Only leagues football-data.org does NOT serve, keyed by API-Football league id. */
export const apiFootballLeagues: Readonly<Record<number, ApiFootballLeague>> = {
  203: { code: "TSL", name: "Süper Lig" },
  253: { code: "MLS", name: "Major League Soccer" },
  307: { code: "KSA", name: "Saudi Pro League" },
  144: { code: "BJL", name: "Jupiler Pro League" },
  179: { code: "SPL", name: "Scottish Premiership" },
  128: { code: "ARG", name: "Liga Profesional" },
  262: { code: "LMX", name: "Liga MX" },
  98: { code: "J1", name: "J1 League" },
  188: { code: "ALG", name: "A-League Men" },
  119: { code: "DSL", name: "Superliga" },
  113: { code: "ALS", name: "Allsvenskan" },
};

export interface ApiFootballFixture {
  fixture: { id: number; date: string; status: { short: string } };
  league: { id: number; name: string; country?: string | null };
  teams: { home: { id?: number | null; name?: string | null }; away: { id?: number | null; name?: string | null } };
}

export function parseLeagueAllowlist(value: unknown): number[] {
  let raw: unknown = value;
  if (typeof value === "string") {
    try { raw = JSON.parse(value); } catch { return Object.keys(apiFootballLeagues).map(Number); }
  }
  if (!Array.isArray(raw)) return Object.keys(apiFootballLeagues).map(Number);
  const ids = raw.filter((id): id is number => Number.isSafeInteger(id) && id in apiFootballLeagues);
  return [...new Set(ids)];
}

/** Dates the Free plan serves: yesterday, today, tomorrow (UTC), intersected with the requested [from, to). */
export function servedDates(dateFrom: string, dateTo: string, now: Date = new Date()): string[] {
  const day = (offset: number) => new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + offset)).toISOString().slice(0, 10);
  const allowed = new Set([day(-1), day(0), day(1)]);
  const dates: string[] = [];
  for (let cursor = Date.parse(`${dateFrom}T00:00:00Z`); cursor <= Date.parse(`${dateTo}T00:00:00Z`); cursor += 86_400_000) {
    const iso = new Date(cursor).toISOString().slice(0, 10);
    if (allowed.has(iso)) dates.push(iso);
  }
  return dates;
}

export function fixtureStatus(short: string): string {
  switch (short) {
    case "TBD": case "NS": return "scheduled";
    case "1H": case "HT": case "2H": case "ET": case "BT": case "P": case "LIVE": return "in_progress";
    case "FT": case "AET": case "PEN": return "finished";
    case "PST": return "postponed";
    case "CANC": case "ABD": return "cancelled";
    case "SUSP": case "INT": return "suspended";
    case "AWD": case "WO": return "awarded";
    default: return "scheduled";
  }
}

export function isUsableApiFootballFixture(item: ApiFootballFixture, allowed: ReadonlySet<number>): boolean {
  return allowed.has(item.league?.id)
    && Number.isSafeInteger(item.fixture?.id) && item.fixture.id > 0
    && Number.isFinite(Date.parse(item.fixture.date))
    && Boolean(item.teams?.home?.name) && Boolean(item.teams?.away?.name);
}

/** Firestore document body (kickoffAt is a Date here; the caller converts it to a Timestamp). */
export function normalizeApiFootballFixture(item: ApiFootballFixture): Record<string, unknown> & { kickoffAt: Date } {
  const league = apiFootballLeagues[item.league.id] as ApiFootballLeague;
  return {
    source: "api-football",
    sourceMatchId: item.fixture.id,
    fixtureVersion: 1,
    analysisAvailable: false,
    competitionId: league.code,
    competitionName: league.name,
    competitionAreaName: item.league.country ?? null,
    // Team ids are namespaced so they can never collide with football-data.org team ids (favorite team matching).
    homeTeam: { id: `af:${item.teams.home.id ?? `h${item.fixture.id}`}`, name: item.teams.home.name },
    awayTeam: { id: `af:${item.teams.away.id ?? `a${item.fixture.id}`}`, name: item.teams.away.name },
    kickoffAt: new Date(item.fixture.date),
    status: fixtureStatus(item.fixture.status?.short ?? ""),
    latestSnapshotId: null,
  };
}

export class ApiFootballError extends Error {
  constructor(public readonly status: number, public readonly detail: string) {
    super(`API_FOOTBALL_${status}`);
  }
}

export interface ApiFootballDayResult {
  readonly fixtures: ApiFootballFixture[];
  readonly remainingToday: number | null;
}

export async function fetchApiFootballDay(
  key: string,
  date: string,
  fetchImplementation: typeof fetch = fetch,
): Promise<ApiFootballDayResult> {
  if (key.trim().length === 0) throw new Error("API_FOOTBALL_SECRET_UNAVAILABLE");
  const response = await fetchImplementation(`https://v3.football.api-sports.io/fixtures?date=${encodeURIComponent(date)}`, {
    headers: { "x-apisports-key": key },
    signal: AbortSignal.timeout(8_000),
  });
  if (!response.ok) throw new ApiFootballError(response.status, "http");
  const body = await response.json() as { errors?: unknown; response?: ApiFootballFixture[] };
  // The API reports plan/quota problems in `errors` with HTTP 200 (object) or as an empty array when fine.
  const errors = body.errors;
  const failed = errors && !Array.isArray(errors) && Object.keys(errors as object).length > 0;
  if (failed) throw new ApiFootballError(200, JSON.stringify(errors).slice(0, 200));
  const remaining = Number(response.headers.get("x-ratelimit-requests-remaining"));
  return { fixtures: Array.isArray(body.response) ? body.response : [], remainingToday: Number.isFinite(remaining) ? remaining : null };
}
