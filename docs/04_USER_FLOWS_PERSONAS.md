# Phase 1 — Personas and User Flows

## Personas

### Matchday Regular

Follows major leagues and Champions League. Core competitions are free to browse; Premium trigger is needing more monthly analyses or longer history—not Champions League access.

### Data-Curious Fan

Wants percentage distributions, evidence, freshness and limitations. Converts when repeated comparison/history is valuable.

### Casual Viewer

Needs fast, localized explanation without statistical jargon. May remain Free.

## Primary flow

1. App creates/restores anonymous session.
2. User selects locale automatically or in Settings.
3. Fixture list loads supported, eligible matches.
4. Detail shows data snapshot availability/freshness before generation.
5. User taps “Generate analysis”. UI shows quota impact before confirmation where required.
6. Backend returns cached `ready` result or request status.
7. UI observes `queued → generating → validating → ready` and displays probabilities, evidence, limitations, generated time and disclaimer.
8. First successful view creates history/usage entry; repeat view of the same version is free.

## Required alternative flows

- No fixtures: empty state with date/league reset.
- Fixture provider unavailable/offline: cached content + freshness warning; no new generation offline.
- Insufficient/stale snapshot: generation disabled with a localized reason.
- Postponed: fixture version increments; old analysis is stale and a fresh request may be made when data is ready.
- Started/cancelled/suspended: no new analysis; previous result marked historical/expired.
- Concurrent devices: both observe the same request; a single invocation runs.
- Retryable failure: retry action uses the same idempotency context and no duplicate charge.
- Permanent validation/policy failure: no result, quota reservation released, support/report path available.
- Quota exhausted: paywall explains view quota; cached status is irrelevant to copy.
- Purchase failed/cancelled/billing issue: preserve context and show restore/manage-subscription actions.
- Account link collision: backend merge protocol, explicit confirmation, no silent data loss.
- Credential revoked: anonymous fallback and re-auth prompt.
- Account deletion: re-auth, consequences, request receipt and completion state.

## Settings in V1

- Language: System/TR/EN/ES/FR.
- Subscription status, restore/manage subscription.
- Privacy, Terms, support, AI limitations.
- Sign in/link account, delete account.

Notification preference is not shown while notifications are out of scope.
