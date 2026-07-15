# Firestore Schema Draft

## Collections

```text
users/{uid}
  schemaVersion, createdAt, lastSeenAt, authProviders, locale, deletionStatus
  private/entitlement
    plan, status, expiresAt, source, updatedAt
  private/quota
    periodUTC, plan, monthlyLimit, used, remaining, resetsAt, updatedAt
  history/{analysisVersionId}
    analysisId, versionId, firstViewedAt, lastViewedAt, fixtureKey

fixtures/{fixtureKey}
  schemaVersion, provider, competitionId, teams, kickoffAt, status,
  fixtureVersion, latestSnapshotId, updatedAt
  snapshots/{snapshotId}
    snapshotVersion, dataSnapshotAt, sections, provenance, contentHash

analyses/{analysisId}
  schemaVersion, fixtureKey, fixtureVersion, snapshotId, snapshotVersion,
  promptVersion, modelVersion, state, generatedAt, validUntil, staleReason,
  canonicalMarkets, confidence, dataAvailability, limitations
  locales/{locale}
    rationale, moderationStatus, localizedAt, localizationVersion

analysisRequests/{requestId}
  uid, fixtureKey, locale, idempotencyKeyHash, analysisId, state,
  attempt, leaseOwner, leaseExpiresAt, errorCode, createdAt, updatedAt

analysisCache/{cacheKeyHash}
  analysisId, versionId, validUntil, state, createdAt

usageLedger/{entryId}
  uid, periodUTC, analysisVersionId, kind, requestId, createdAt

quotaReservations/{reservationId}
  uid, periodUTC, analysisVersionId, requestId, state, createdAt, committedAt, releasedAt

subscriptions/{uid}
  entitlement, productId, originalTransactionIdHash, status, expiresAt, eventAt

feedback/{feedbackId}
  uidHash, analysisVersionId, rating, reasonCode, createdAt

adminAudit/{eventId}
  actor, action, targetHash, reason, createdAt
```

## Ownership and rules

- Public authenticated read: eligible fixture summaries and `ready`/non-expired analysis projection only.
- User-only read: own profile, entitlement projection, history and quota projection.
- Client writes: narrowly validated preferences and feedback only. Generation uses callable Function; client cannot write request/state/cache/ledger/subscription.
- Admin SDK is required for snapshots, analyses, state transitions, quota and entitlement.
- Rules validate allowed fields, types, immutable IDs and `request.auth.uid` ownership. App Check and rate limiting live additionally at Function boundary.

## Data minimization

- Common analysis/cache holds no uid.
- Store provider references/hashes, not unnecessary raw licensed payloads where contract prohibits it.
- `idempotencyKeyHash` and transaction hashes are one-way identifiers.
- Server timestamps only for authoritative lifecycle fields.

## Indexes

- fixtures: `(competitionId, status, kickoffAt)` and `(status, kickoffAt)`.
- user history: `lastViewedAt desc`.
- requests: `(uid, createdAt desc)` and `(state, leaseExpiresAt)` for recovery.
- immutable ledger: `(uid, periodUTC)`; unique semantics enforced by deterministic document ID/transaction.
- quota reservation: `(state, expiresAt)` for recovery/release. `usageLedger` commit documents are immutable; reservation lifecycle is kept separately.
- analyses/cache: direct hash lookup; operational stale sweeps on `(state, validUntil)`.

## Retention/cleanup

Scheduled jobs expire leases, mark past-kickoff analyses expired, purge request diagnostics, delete user links after account deletion, and aggregate/delete shared analyses per policy. TTL policies are configured on eligible collections but business state transitions do not rely solely on asynchronous Firestore TTL deletion.
