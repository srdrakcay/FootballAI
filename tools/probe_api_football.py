"""Read-only coverage probe for the API-Football (api-sports.io) free trial key.

It answers the questions the integration depends on, using about 25 of the 100 daily requests:
  1. Does the key work, and what are the plan's limits (/status)?
  2. For each target league: which id/name/country is it, which seasons are open, is the current
     season returned, and which data does the coverage flag promise (fixtures, standings, h2h, form)?
  3. Does a date query return real fixtures on this plan?

Usage (key stays in the environment, never printed or written to disk):
    API_FOOTBALL_KEY=... python3 tools/probe_api_football.py [YYYY-MM-DD]
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import date

BASE = "https://v3.football.api-sports.io"
# League ids as commonly listed by API-Football. The probe prints the real name/country so wrong ids show up.
TARGETS = {
    203: "Turkey - Süper Lig",
    253: "USA - MLS",
    307: "Saudi Arabia - Pro League",
    144: "Belgium - Pro League",
    179: "Scotland - Premiership",
    128: "Argentina - Liga Profesional",
    262: "Mexico - Liga MX",
    98: "Japan - J1 League",
    188: "Australia - A-League",
    119: "Denmark - Superliga",
    113: "Sweden - Allsvenskan",
}


def get(path: str, params: dict | None = None):
    url = BASE + path + ("?" + urllib.parse.urlencode(params) if params else "")
    request = urllib.request.Request(url, headers={"x-apisports-key": os.environ["API_FOOTBALL_KEY"]})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = json.loads(response.read())
            return body, response.headers
    except urllib.error.HTTPError as error:
        return {"errors": {"http": error.code}, "response": []}, error.headers


def main() -> int:
    if not os.environ.get("API_FOOTBALL_KEY"):
        print("Set API_FOOTBALL_KEY in the environment first.")
        return 2
    day = sys.argv[1] if len(sys.argv) > 1 else date.today().isoformat()

    status, headers = get("/status")
    account = status.get("response") or {}
    if status.get("errors"):
        print("AUTH/PLAN ERROR:", status["errors"])
        return 1
    subscription = account.get("subscription", {}) if isinstance(account, dict) else {}
    requests_info = account.get("requests", {}) if isinstance(account, dict) else {}
    print(f"plan={subscription.get('plan')} active={subscription.get('active')} "
          f"requests today={requests_info.get('current')}/{requests_info.get('limit_day')}")

    print(f"\n{'id':>4}  {'league':<34} {'country':<14} seasons open (latest)  current  fixtures  standings  h2h  form")
    open_leagues = []
    for league_id, expected in TARGETS.items():
        body, _ = get("/leagues", {"id": league_id})
        entries = body.get("response") or []
        if not entries:
            print(f"{league_id:>4}  NOT FOUND (expected {expected}) errors={body.get('errors')}")
            continue
        entry = entries[0]
        seasons = entry.get("seasons", [])
        current = next((s for s in seasons if s.get("current")), seasons[-1] if seasons else {})
        coverage = current.get("coverage", {})
        has = lambda flag: "yes" if flag else "no"
        fixtures_cov = coverage.get("fixtures", {})
        print(f"{league_id:>4}  {entry['league']['name']:<34} {entry['country']['name']:<14} "
              f"{current.get('year')!s:<22} {has(current.get('current')):<8} "
              f"{has(fixtures_cov.get('events')):<9} {has(coverage.get('standings')):<10} "
              f"{has(fixtures_cov.get('statistics_fixtures') or coverage.get('predictions')):<4} {has(coverage.get('players'))}")
        open_leagues.append((league_id, current.get("year")))

    print(f"\nfixtures on {day} (one call, all leagues):")
    body, headers = get("/fixtures", {"date": day})
    fixtures = body.get("response") or []
    print(f"  returned={len(fixtures)} errors={body.get('errors')}")
    wanted = {league_id for league_id, _ in open_leagues}
    hits = [f for f in fixtures if f["league"]["id"] in wanted]
    for fixture in hits[:12]:
        print(f"  {fixture['league']['name']}: {fixture['teams']['home']['name']} - {fixture['teams']['away']['name']} "
              f"({fixture['fixture']['status']['short']})")
    print(f"  of which in target leagues: {len(hits)}")

    print("\nremaining today:", headers.get("x-ratelimit-requests-remaining"), "| per minute:", headers.get("X-RateLimit-Remaining"))
    print("\nVERDICT: usable if the plan is active, the target leagues show the CURRENT season, and the date query returns")
    print("fixtures in them. If seasons are capped to past years, the free plan cannot serve live fixtures.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
