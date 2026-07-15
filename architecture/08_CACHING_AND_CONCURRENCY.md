# Caching, Versioning and Concurrency

## Version identity

```text
AnalysisVersion = hash(
  fixtureKey,
  fixtureVersion,
  snapshotVersion/contentHash,
  schemaVersion,
  promptVersion,
  modelAliasVersion
)
```

Locale is excluded from canonical probability identity and included only in localized-artifact identity. Never use fixture ID alone as cache key.

## Cache policy

- L1 iOS memory/disk: read-through copy of public ready projection, bounded size, honors `validUntil` and server state.
- L2 Firestore analysis cache: authoritative current analysis pointer.
- Provider/AI response is not blindly cached; only validated canonical result is promotable.
- `stale-while-revalidate` may show a clearly marked previous result on history screens, but eligibility/detail never labels it current.
- Kickoff/status and material snapshot changes override TTL immediately.

## Single-flight algorithm

1. Compute deterministic cache key.
2. Firestore transaction checks ready valid cache.
3. If no hit, create deterministic `analysisRequests/{cacheKeyHash}` or join existing non-terminal request.
4. Lease uses `ownerId`, `leaseExpiresAt`, `attempt` and compare-and-set transaction.
5. Only lease owner invokes AI. Waiters observe state.
6. Completion transaction is idempotent; a late worker cannot overwrite a newer lease/result.

Firestore has no uniqueness constraint, so deterministic IDs plus transactions enforce uniqueness. Scheduled recovery handles abandoned leases. Maximum attempts and absolute deadline prevent retry storms.

## Idempotency and quota

- Callable idempotency: `uid + clientRequestID`; analysis work identity: version hash.
- Ledger identity: `uid + analysisVersion + UTC period`.
- Reservation and request creation share a transaction. Commit occurs only when result is deliverable to that user.
- Joining a request does not create duplicate generation or duplicate ledger entry.
- Model invocation cost and user view quota are separate metrics.

## Invalidations

Material changes: kickoff/status, team/opponent, competition/season, snapshot content/freshness, prompt/model/schema. Config service emits only allowlisted versions. Admin can mark a version stale with reason; it cannot mutate canonical probabilities in place—correction creates a new version.
