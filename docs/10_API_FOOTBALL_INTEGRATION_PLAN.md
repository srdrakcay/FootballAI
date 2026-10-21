# API-Football as a second fixtures provider — integration plan

Status: plan only. Nothing here is implemented. Gate 0 (probe) decides whether it is worth building.

## Why

football-data.org (current provider) only returns the 12 competitions of its plan, so the list has no Süper Lig, MLS, Saudi, Belgian, Scottish, Argentine, Mexican, Japanese, Australian or Nordic leagues. API-Football (api-sports.io) lists 1,200+ leagues on all plans, including a free plan of 100 requests/day. Unverified until the probe runs: whether the free plan returns the **current** season, and whether free-plan use in a commercial app is allowed.

## Gate 0 — prove it works (about 25 requests, no code in the app)

```bash
API_FOOTBALL_KEY=<trial key> python3 tools/probe_api_football.py
```

Go only if all of these hold: plan active; the target leagues (Süper Lig 203, MLS 253, Saudi 307, Belgium 144, Scotland 179, Argentina 128, Mexico 262, Japan 98, Australia 188, Denmark 119, Sweden 113) show the current season; the date query returns fixtures in them; standings coverage is available. Also e-mail api-sports.io: "may the free plan be used in a published iOS app that shows fixtures and AI analyses built from the data?" and keep the answer. If the plan is capped to past seasons, stop: the options become the paid plan or a football-data.org upgrade.

## Design

**Provider abstraction (server only).** Today `syncFixtures`, `getFixtureInsights` and the analysis snapshot builder call `FootballDataClient` directly. Introduce `FixtureProvider` with `fetchWindow(dateFrom, dateTo)`, `insights(fixture)` (form, head-to-head, standings) and `analysisSnapshot(fixture)`. Keep the football-data adapter unchanged behind it; add `apiFootballProvider`.

**Which provider owns which league.** Football-data.org stays primary for every competition it serves. API-Football is used only for league ids on an allowlist of leagues football-data.org lacks. That removes cross-provider duplicates, so no fuzzy name matching is needed.

**Fixture documents.** Same `fixtures/{key}` collection, `key = api-football:<fixture.id>` (matches the existing key regex), `source = "api-football"`, `sourceMatchId`, `competitionId` from a small catalog (`leagueCatalog.ts`: AF league id → app code such as `TSL`, `MLS`, plus area name from `league.country`). The client already groups unknown codes by area and has `TSL`/`MLS` in its category tables, so no client release is needed for the list.

**Field mapping.** `fixture.date` → `kickoffAt`; `fixture.status.short`: NS/TBD → scheduled/timed, 1H/HT/2H/ET/P/LIVE → in_progress, FT/AET/PEN → finished, PST → postponed, CANC → cancelled, SUSP/INT → suspended, AWD/WO → awarded; `teams.home/away.{id,name}`; `league.{id,name,country}`.

**Analysis input.** The AI prompt already works from a normalized snapshot (`recentForm`, `headToHead`, `standings`, optional lineups/weather). Build the same snapshot from `GET /fixtures?team={id}&last=5`, `GET /fixtures/headtohead?h2h={a}-{b}&last=5` and `GET /standings?league=&season=`. Sections the provider cannot supply are marked unavailable; the validator already enforces that the model only cites available sections.

**Secrets and flags.** `API_FOOTBALL_KEY` in Secret Manager (`firebase functions:secrets:set API_FOOTBALL_KEY`). Remote Config: `provider_api_football_enabled` (default false) and `api_football_league_ids` (JSON array, capped), so it can be switched off without a deploy.

## Request budget (free plan: 100/day)

| Call | When | Cache | Budget/day |
|---|---|---|---|
| `/fixtures?date=` (all leagues, filter server-side) | on `syncFixtures` for a day | 60 min per date | 24-48 |
| `/standings?league&season` | only for allowlisted leagues with matches that day | 12 h | 10-15 |
| form + head-to-head | lazily when a user opens/unlocks a match from this provider | 24 h per team/pair | at most 30-40 |

The existing 15-minute window is too frequent here (96 calls/day for one date). Use 60 minutes for the secondary provider, serve stale cache on quota errors (same fallback `syncFixtures` already has), and track `x-ratelimit-requests-remaining` in a Firestore counter; at <10 remaining skip refreshes. If real traffic exceeds this, the paid tier is the next step, not a code change.

## Work breakdown

1. Gate 0 probe + vendor e-mail (you; about 30 minutes).
2. `FixtureProvider` interface and football-data adapter, behaviour-preserving (existing tests must pass unchanged).
3. API-Football client (timeouts, retry, quota header handling, 429 backoff) with fake-fetch unit tests like `footballDataClient.test.ts`.
4. `leagueCatalog.ts`, status/field mapping, fixture normalization tests.
5. `syncFixtures` merge: football-data first, then allowlisted API-Football leagues; per-source error isolation (one provider failing must not blank the list).
6. Insights and analysis snapshot from API-Football, including the unavailable-section handling.
7. Secret, Remote Config flags, staged rollout (flag on for your own device first), watch the `analysis.*` logs.
8. Attribution/terms text in the app's legal screen if the vendor requires it.

## Risks

- Free plan may not cover the current season or may forbid commercial use (Gate 0 decides).
- 100 requests/day is tight; cache design above is the mitigation.
- Standings/form coverage varies per league (the probe prints the coverage flags); leagues without it will give thinner analyses, shown as limitations.
- ESPN's public endpoints cover these leagues too but are unlicensed; deliberately not part of this plan.

## Gate 0 result (probe run 2026-10-21, free trial key, plan Free, 100 requests/day)

Works:
- Key valid; 9 of 11 target leagues expose the current season (Süper Lig 203, MLS 253, Saudi 307, Belgium 144, Scotland 179, Argentina 128, Mexico 262, Japan 98, Australia 188); Denmark 119 and Sweden 113 exist too (their probe calls hit the per-minute limit, ids confirmed afterwards).
- `GET /fixtures?date=` returns every league in one call: 273 matches on 2026-10-21, 232 on 10-20, 159 on 10-22 (15 / 8 in the target leagues on the first two dates I counted).

Blocked on the Free plan (API error text, verbatim in substance):
- Dates: only yesterday to tomorrow ("try from 2026-10-20 to 2026-10-22"). The app's day strip spans 5 days, so +2/+3 days cannot be served.
- `last` parameter: "Free plans do not have access to the Last parameter", so recent form and head-to-head via `last=5` fail.
- Standings: seasons 2022-2024 only ("do not have access to this season"); 2026 standings fail.
- Rate limit: about 10 requests/minute (429 when exceeded).

Consequence: on Free, the list can show the extra leagues for a 3-day window, but the analysis snapshot for those fixtures would have no form, head-to-head or standings, so `DATA_INSUFFICIENT` would block them. Real analyses for these leagues need a paid plan (verify price and limits on api-football.com before buying) or another data source for form/standings.

Options:
A. Free, list-only: add the extra leagues as browse-only (3-day window), analysis button replaced by an explanatory state. Cheap, honest, useful for discovery.
B. Paid API-Football plan: full list window, standings, form, head-to-head for all seasons; follow the design above.
C. Stay on football-data.org only.
