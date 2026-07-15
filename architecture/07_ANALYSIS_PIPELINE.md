# Analysis Generation Pipeline

## State machine

```text
not_started -> queued -> generating -> validating -> ready
                  |          |             |
                  +----------+-------------+-> failed_retryable -> queued
                                             -> failed_permanent
ready -> stale -> queued (new version)
any non-terminal -> cancelled (fixture becomes ineligible/admin)
ready/stale -> expired (kickoff/retention)
```

Only backend state machine methods transition state. Each transition checks current state/version and writes an audit timestamp. Terminal state for a request is `ready`, `failed_permanent`, `cancelled` or `expired`; retryable attempts are bounded.

## End-to-end steps

1. Callable receives `fixtureKey`, locale, client request UUID and disclaimer version.
2. Verify Auth, App Check, payload, minimum app version and rate limits.
3. Resolve authoritative fixture, latest eligible snapshot, entitlement and bounded config.
4. Compute version tuple/cache key. Return current ready hit if available.
5. Transactionally create/find request, quota reservation and single-flight lease.
6. Lease owner builds prompt from the normalized snapshot and server prompt registry.
7. Resolve approved model alias and Secret Manager credential; call provider with timeout/budget.
8. Parse and validate JSON Schema, probability invariants, evidence refs, prohibited claims and moderation.
9. One constrained repair may run; then classify retryable/permanent.
10. Transaction writes canonical analysis, locale artifact, cache pointer, request `ready`, committed ledger and history link.
11. Observers receive state. Non-owner concurrent callers attach to the request/result.

## Transition rules

- `queued → generating`: valid unexpired lease and attempt increment.
- Heartbeat extends lease only within maximum generation deadline.
- Worker death: recovery job moves expired lease to `failed_retryable`; retry obtains a new lease.
- Fixture/snapshot version change during generation: result is not promoted; request becomes cancelled/stale and may enqueue current version.
- Quota reservation expires/releases on any non-delivery terminal failure.
- Client closing the screen has no effect; request is server-owned.

## Failure classification

- Retryable: provider 429/5xx, transient network, lease loss before side effect, temporary localization failure.
- Permanent: fixture ineligible, insufficient input, unsupported schema/prompt/model ID, policy violation after repair, invalid request.
- Operational/config failures default closed and page the relevant owner; raw provider error is never sent to client.

## Localized rationale

Canonical probabilities are committed once. If requested locale artifact is missing, create it from canonical markets + evidence set under a localization-specific single-flight key. Localization failure may fall back to English without changing canonical analysis state.
