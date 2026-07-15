# Phase 2 — Architecture Package

Bu klasör Phase 1 ürün kararlarının uygulanabilir teknik kontratıdır.

1. [01_OVERVIEW.md](01_OVERVIEW.md) — boundaries, Clean Architecture + MVVM, DI.
2. [02_MODULES_AND_FOLDERS.md](02_MODULES_AND_FOLDERS.md) — module/folder layout and dependencies.
3. [03_DOMAIN_CONTRACTS.md](03_DOMAIN_CONTRACTS.md) — entities, repositories and use cases.
4. [04_FIRESTORE_SCHEMA.md](04_FIRESTORE_SCHEMA.md) — collections, indexes, ownership and retention.
5. [05_REMOTE_CONFIG_AND_LOCALIZATION.md](05_REMOTE_CONFIG_AND_LOCALIZATION.md) — typed configuration and four-locale architecture.
6. [06_SECURITY_AND_SECRETS.md](06_SECURITY_AND_SECRETS.md) — trust boundaries, Secret Manager and rotation.
7. [07_ANALYSIS_PIPELINE.md](07_ANALYSIS_PIPELINE.md) — orchestration and state machine.
8. [08_CACHING_AND_CONCURRENCY.md](08_CACHING_AND_CONCURRENCY.md) — versioning, TTL, idempotency and single-flight.
9. [09_ERRORS_AND_TESTING.md](09_ERRORS_AND_TESTING.md) — error taxonomy, observability and tests.
10. [10_PHASE2_CHECKLIST.md](10_PHASE2_CHECKLIST.md) — implementation readiness gate.

## Architecture decisions

- Firebase SDK types stop at Data layer boundaries.
- ViewModels depend on use-case protocols, never repositories/SDKs directly.
- Composition root creates concrete dependencies; tests inject fakes.
- Client requests analysis; only backend builds prompt, reads secrets, calls model, validates output and mutates quota/state.
- Firestore documents are API contracts and include explicit schema versions.
