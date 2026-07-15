# Error Model, Observability and Testing

## Typed public error model

```text
AUTH_REQUIRED
APP_CHECK_FAILED
RATE_LIMITED(retryAfter)
FIXTURE_NOT_FOUND
FIXTURE_INELIGIBLE(reason)
DATA_INSUFFICIENT(missingCodes)
ANALYSIS_STALE
QUOTA_EXHAUSTED(resetAt)
ENTITLEMENT_UNAVAILABLE
GENERATION_IN_PROGRESS(requestId)
GENERATION_FAILED_RETRYABLE(retryAfter)
GENERATION_FAILED_PERMANENT(referenceId)
CONFIG_UNAVAILABLE
NETWORK_OFFLINE
UPDATE_REQUIRED
UNKNOWN(referenceId)
```

Domain maps transport/provider errors into safe codes. UI maps codes to String Catalog keys and recovery actions. Provider messages, prompts, stack traces and secrets never cross the boundary.

## Observability

- Correlation IDs across callable → request → invocation → validator → ledger.
- Metrics: transitions, queue/generation/validation latency, retry, lease takeover, cache hit, quota reservation release, schema/policy failures, locale fallback and cost.
- Logs contain IDs/hashes and error codes, not raw secrets, PII or complete prompt/response.
- Alerts: generation failure/latency, validation spike, entitlement webhook lag, App Check rejection anomaly, config parse failure and cost budget.

## Test pyramid

### Unit

- Probability invariants, TTL tiers, version hash, eligibility, quota period/ledger idempotency.
- DTO mapping/unknown enums, Remote Config validation/clamps/fallback.
- ViewModel state transitions/cancellation and locale formatting.
- Secret redaction and error mapping.

### Contract

- JSON Schema golden valid/invalid fixtures.
- Prompt input allowlist and evidenceRefs resolution.
- Canonical probabilities identical across TR/EN/ES/FR artifacts.
- Backend/iOS DTO compatibility for current and previous supported schema.

### Integration/emulator

- Firestore Rules deny client writes to analyses/ledger/entitlement.
- Two/100 concurrent requests produce one invocation and one ledger charge per user/version.
- Expired lease recovery; late worker cannot overwrite.
- Quota release on failure and commit on ready.
- RevenueCat signed webhook replay/order/grace/refund scenarios.
- Account link/delete and retention jobs.

### UI/snapshot/E2E

- Loading/empty/offline/stale/failure/paywall/ready flows.
- Four locales, pseudolocalization, Dynamic Type, VoiceOver and small screens.
- Cache hit/miss, app termination during generation, second-device observation.
- Staging smoke test with synthetic fixtures and provider sandbox.

## CI gates

Format/lint, unit, schema/contract, emulator rules, backend integration, Swift snapshot, dependency/secret scan and migration compatibility. Production deploy requires staging canary, rollback artifact and Remote Config/Secret Manager change audit.
