# Modules and Folder Structure

Recommended Swift Package modules:

```text
FootballAIApp/
  App/
    AppCompositionRoot.swift
    AppRouter.swift
  Resources/
    Localizable.xcstrings
Packages/
  CoreDomain/           # IDs, clocks, locale, common errors; no Firebase
  CoreNetworking/       # callable transport contracts/adapters
  CorePersistence/      # local cache abstraction
  CoreDesignSystem/     # UI components/tokens/accessibility
  CoreLocalization/     # LocaleProvider, formatters, string keys
  CoreObservability/    # logger/metrics protocols; redaction
  FeatureFixtures/
    Domain/{Entities,Repositories,UseCases}/
    Data/{DTOs,DataSources,Repositories,Mappers}/
    Presentation/{Views,ViewModels,Models}/
  FeatureAnalysis/      # same three-layer layout
  FeatureHistory/
  FeatureSubscription/
  FeatureSettings/
  FirebaseAdapters/     # Auth, Firestore, Functions, RemoteConfig, AppCheck
Tests/
  Unit/
  Integration/
  Snapshot/
  ContractFixtures/
functions/
  src/
    analysis/{orchestrator,stateMachine,validator,promptRegistry}/
    fixtures/{ingestion,normalization,freshness}/
    entitlement/{webhook,resolver}/
    quota/{ledger,reservation}/
    config/{schema,loader}/
    security/{appCheck,rateLimit,secrets}/
    shared/{errors,logging,clock,ids}/
  test/
firestore/
  firestore.rules
  firestore.indexes.json
remote-config/
  defaults.json
  schema.json
```

## Dependency direction

- Features may depend on Core modules.
- Presentation → Domain; Data → Domain. Domain depends only on `CoreDomain`/standard library.
- Feature modules do not import one another's Data layer. Cross-feature navigation uses app routes; shared concepts move to CoreDomain.
- `FirebaseAdapters` implements narrow protocols owned by relevant Domain/Data boundary.
- Backend shares JSON Schema artifacts with iOS contract tests through generated fixtures, not copied hand-edited models.

## Build discipline

- Strict concurrency checking and Sendable models.
- SwiftFormat/SwiftLint, dependency graph check and license scan in CI.
- Secrets and generated Firebase config are environment-managed; no credentials in packages.
