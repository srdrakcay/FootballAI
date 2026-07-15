# Architecture Overview

## Layers

```text
SwiftUI View
  -> @MainActor ViewModel (UI state, intents)
    -> UseCase protocol (business operation)
      -> Repository protocol (Domain)
        -> Repository implementation (Data)
          -> Firebase/HTTP/local cache data sources

Cloud Functions callable/HTTP entry
  -> Auth + App Check + rate limit
    -> Analysis Orchestrator
      -> Snapshot/Entitlement/Quota/Lock services
      -> Prompt registry + model gateway
      -> Schema/policy validator
      -> Firestore state/cache/history
```

## Responsibilities

- **Presentation:** navigation, localized display models, loading/empty/error/ready states, accessibility.
- **Domain:** framework-light entities, policies, repository/use-case contracts and typed errors.
- **Data:** DTO mapping, Firebase adapters, remote/local caching and observation streams.
- **Backend:** authorization, provider ingestion, prompt construction, secrets, AI invocation, validation, ledger and authoritative transitions.

## MVVM rules

- ViewModel exposes immutable `ViewState` and intent methods.
- Async work is cancellable Swift concurrency; UI cancellation does not cancel backend generation.
- No Firestore snapshots/models in Views.
- Navigation routes are value types; deep-link resolution is outside feature ViewModels.
- Formatting/localization is injected through presentation mappers/formatters.

## Dependency injection

Use initializer injection and a small manual `AppContainer`; no service locator in feature code.

```swift
protocol DependencyContainer {
    var observeFixtures: ObserveFixturesUseCase { get }
    var requestAnalysis: RequestAnalysisUseCase { get }
    var observeAnalysis: ObserveAnalysisUseCase { get }
}
```

`AppCompositionRoot` selects live/staging/mock implementations. Firebase configuration occurs once. SwiftUI Environment may carry feature factories, not global mutable SDK objects.

## Environments

Separate Firebase projects, bundle IDs, Secret Manager secrets, Remote Config templates and RevenueCat apps for dev/staging/prod. Production data/secrets are never used by previews or tests.
