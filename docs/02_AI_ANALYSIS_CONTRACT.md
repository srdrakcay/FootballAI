# Phase 1 — AI Analysis Contract

## Input: `AnalysisInputSnapshot`

```json
{
  "snapshotId": "snap_01",
  "snapshotVersion": 7,
  "fixture": {
    "fixtureKey": "provider:2026:12345",
    "fixtureVersion": 4,
    "kickoffAt": "2026-08-12T19:00:00Z",
    "status": "timed",
    "competitionId": "UCL",
    "homeTeamId": "A",
    "awayTeamId": "B"
  },
  "dataSnapshotAt": "2026-08-12T12:00:00Z",
  "sections": {
    "recentForm": {"status": "available", "observedAt": "...", "data": {}},
    "headToHead": {"status": "available", "observedAt": "...", "data": {}},
    "standings": {"status": "available", "observedAt": "...", "data": {}},
    "squadAvailability": {"status": "unavailable", "observedAt": null, "data": null},
    "lineups": {"status": "unavailable", "observedAt": null, "data": null},
    "weather": {"status": "available", "observedAt": "...", "data": {}}
  },
  "provenance": [{"sourceId": "licensed-provider", "retrievedAt": "..."}]
}
```

Serbest metin kullanıcı iddiası V1'de input değildir. Backend allowlist dışı alanları, HTML/instruction metinlerini ve PII'ı prompttan çıkarır. Her section şemaya, freshness limitine ve provenance'a göre doğrulanır.

## Prompt policy

System/developer prompt şu değişmez kuralları içerir:

1. Yalnızca verilen JSON'u kullan.
2. Eksik alanı tahmin etme veya genel bilgiden tamamlama.
3. Kesin sonuç, bahis tavsiyesi veya garanti dili kullanma.
4. Sadece belirtilen JSON output schema'sını üret.
5. Her rationale claim'ini `evidenceRefs` ile mevcut input alanına bağla.
6. Veri zayıfsa confidence'ı düşür ve limitation ekle.

Prompt injection savunması: provider'dan gelen metinler data olarak delimiter içinde verilir; model talimatı olarak yorumlanmaz. Output yine deterministik validator'dan geçer.

## Output: `AnalysisResultV2`

```json
{
  "schemaVersion": "2.0",
  "analysisId": "ana_01",
  "status": "ready",
  "fixtureKey": "provider:2026:12345",
  "fixtureVersion": 4,
  "snapshotId": "snap_01",
  "snapshotVersion": 7,
  "generatedAt": "2026-08-12T12:01:20Z",
  "validUntil": "2026-08-12T18:00:00Z",
  "promptVersion": "football-v2.1.0",
  "modelVersion": "model-alias-2026-07",
  "language": "tr",
  "markets": {
    "matchResult": {"homePct": 46, "drawPct": 29, "awayPct": 25},
    "goals25": {"overPct": 54, "underPct": 46},
    "bothTeamsScore": {"yesPct": 57, "noPct": 43},
    "likelyScores": [
      {"home": 1, "away": 1, "pct": 12},
      {"home": 2, "away": 1, "pct": 9},
      {"home": 1, "away": 0, "pct": 8}
    ],
    "likelyScoresTotalPct": 29,
    "otherScoresPct": 71
  },
  "confidence": {"level": "medium", "scorePct": 63},
  "rationale": [
    {
      "code": "RECENT_FORM_BALANCE",
      "text": "...",
      "evidenceRefs": ["sections.recentForm", "sections.standings"]
    }
  ],
  "dataAvailability": {
    "recentForm": "available",
    "headToHead": "available",
    "standings": "available",
    "squadAvailability": "unavailable",
    "lineups": "unavailable",
    "weather": "available"
  },
  "limitations": ["SQUAD_DATA_UNAVAILABLE", "LINEUPS_UNAVAILABLE"],
  "moderationStatus": "passed"
}
```

## Validation

- Required fields, enums and types match JSON Schema.
- Every percentage is integer `0...100`.
- Market complements total 100; scoreline total + other = 100.
- Duplicate/invalid scoreline is rejected.
- `evidenceRefs` resolve to `available` input sections.
- Unsupported certainty/betting phrases are rejected by locale-aware policy checks.
- `validUntil <= kickoffAt`; analysis is never served after kickoff.
- Snapshot/fixture/prompt/model/schema version tuple matches request.
- Moderation passes and output size stays within limit.

One repair attempt may be made without charging quota. Failure becomes `failed_retryable` or `failed_permanent`; malformed content is never shown.

## Localization invariant

Canonical numeric result is generated once using stable analysis parameters. Localized `rationale` artifacts use the canonical market values and permitted evidence; translation/localized generation may not alter probabilities. Unsupported locale falls back to English.
