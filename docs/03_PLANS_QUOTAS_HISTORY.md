# Phase 1 — Plans, Quotas, Cache and History

## Plan matrix

| Capability | Free | Premium |
|---|---:|---:|
| V1 core leagues incl. Champions League | Yes | Yes |
| Analysis views | 1/month default | Unlimited normal use |
| Same analysis version reopen | No extra charge | No extra charge |
| History visibility | 30 days | Up to 365 days |
| Abuse/rate limits | Yes | Yes |
| Future extended leagues | Not promised | May be enabled later |

All numeric limits are server-authoritative, bounded Remote Config values. Marketing copy must not promise a league until the production allowlist is enabled.

## Quota behavior

- Product quota is **per-user unique analysis-version view**, independent of shared cache hit/miss.
- `usageLedger/{entryId}` is immutable and uses idempotency key `uid:analysisVersion:period`.
- A reservation is created transactionally when generation/view begins.
- `ready` analysis delivery commits the reservation. Permanent failure or timeout releases it.
- Client cannot update usage counters or entitlement.
- Monthly period uses UTC; UI shows the user's localized renewal date.
- Anonymous-account linking merges ledger/history idempotently; it never doubles rights.

## Cache and validity

Cache key includes:

```text
fixtureKey + fixtureVersion + snapshotVersion + schemaVersion + promptVersion + modelVersion
```

Default TTL policy:

- kickoff > 48h: 24h
- kickoff 6–48h: 6h
- kickoff < 6h: 60m
- any material fixture/snapshot change: immediate stale
- kickoff reached/status becomes ineligible: expired

Remote Config may shorten these bounds, never extend past kickoff. Stale versions remain auditable but are not returned as current.

## History retention

- Free UI visibility: 30 days.
- Premium UI visibility: 365 days; downgrade reverts to 30 days without immediately deleting older records.
- User history links/feedback/usage: deleted or anonymized within 30 days of verified account deletion, subject to legal billing/audit retention.
- Shared analysis cache contains no user PII and may be retained up to 365 days for quality/audit, then deleted/aggregated.
- Raw prompts/responses are not retained by default; diagnostic sampling must be redacted, access-controlled and time-limited.
