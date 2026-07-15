# Phase 2 Completion Checklist

## Product contracts

- [x] Evidence-bounded AI input and probabilistic output schema defined.
- [x] Premium leagues, quota, history, notification and persona decisions reconciled.
- [x] Four locales and numeric localization invariant defined.
- [x] TTL/versioning and exact state machine defined.

## iOS architecture

- [x] Clean Architecture + MVVM boundaries documented.
- [x] DI/composition root strategy documented.
- [x] Module/folder dependency rules documented.
- [x] Repository/use-case protocols and DTO mapping rules drafted.
- [x] Offline/read-only and UI state behavior included.

## Backend/data

- [x] Firestore collections, ownership, indexes and retention drafted.
- [x] Callable orchestration and server-authoritative decisions defined.
- [x] Single-flight lease, idempotency, quota reservation and recovery defined.
- [x] Canonical/localized analysis separation defined.

## Configuration/security

- [x] Remote Config catalog, typed validation and safe defaults defined.
- [x] Secrets explicitly excluded from client/Remote Config/Firestore.
- [x] Secret Manager rotation and incident procedure documented.
- [x] App Check, Auth, rate limit, Rules and logging controls documented.

## Quality

- [x] Public error taxonomy and recovery behavior defined.
- [x] Unit, contract, emulator, concurrency, UI and E2E test strategy defined.
- [x] Trust/legal/analytics deliverables listed.

## Before Phase 3 coding begins

- [x] Product owner approved Free=1/month, Free history=30 days, Premium history=365 days defaults (2026-07-15).
- [ ] Legal approves disclaimer translations, age rating, Terms/Privacy/subscription copy.
- [ ] Data provider confirms core league coverage, licensing and attribution.
- [ ] AI provider/model and regional data-processing constraints are approved.
- [ ] JSON Schema is checked into the implementation repo and code generation strategy selected.
- [ ] Firebase/RevenueCat dev-staging-prod environments and IAM owners are provisioned.
- [ ] Remote Config owners, production rollout gates and on-call rotation are assigned.
- [ ] UX designs cover every primary/alternative flow and all four locales.
- [ ] Cost/load budgets and SLO alert thresholds are approved.

Phase 2 documentation is complete; unchecked items are organizational/provisioning gates for Phase 3, not missing architecture sections.
