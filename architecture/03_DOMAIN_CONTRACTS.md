# Domain Contracts

## Core entities

`Fixture`, `Competition`, `Team`, `DataAvailability`, `AnalysisInputSummary`, `Analysis`, `ProbabilityMarkets`, `Confidence`, `Limitation`, `AnalysisRequest`, `AnalysisState`, `PlanEntitlement`, `QuotaStatus`, `HistoryEntry`, `AppConfiguration`.

Use typed IDs (`FixtureKey`, `AnalysisID`, `SnapshotID`) and UTC `Instant`; avoid raw strings/dates across boundaries.

## Repository protocols (illustrative Swift)

```swift
protocol FixtureRepository: Sendable {
    func observeUpcoming(filter: FixtureFilter) -> AsyncThrowingStream<[Fixture], Error>
    func fixture(id: FixtureKey) async throws -> Fixture
}

protocol AnalysisRepository: Sendable {
    func request(_ command: RequestAnalysisCommand) async throws -> AnalysisRequest
    func observe(requestID: AnalysisRequest.ID) -> AsyncThrowingStream<AnalysisState, Error>
    func analysis(id: Analysis.ID, locale: SupportedLocale) async throws -> Analysis
}

protocol HistoryRepository: Sendable {
    func page(after: HistoryCursor?) async throws -> HistoryPage
    func recordSuccessfulView(analysisID: Analysis.ID) async throws
}

protocol EntitlementRepository: Sendable {
    func current() async throws -> PlanEntitlement
    func observe() -> AsyncThrowingStream<PlanEntitlement, Error>
    func restorePurchases() async throws -> PlanEntitlement
}

protocol AppConfigurationRepository: Sendable {
    func current() async -> AppConfiguration
    func refresh() async throws -> AppConfiguration
}
```

## Use cases

- `ObserveUpcomingFixturesUseCase`
- `GetFixtureDetailUseCase`
- `GetAnalysisEligibilityUseCase` (fixture status + freshness + config + quota)
- `RequestAnalysisUseCase`
- `ObserveAnalysisUseCase`
- `GetLocalizedAnalysisUseCase`
- `ListHistoryUseCase`
- `GetQuotaStatusUseCase`
- `PurchasePremiumUseCase` / `RestorePurchasesUseCase`
- `LinkAppleAccountUseCase` / `DeleteAccountUseCase`
- `SubmitAnalysisFeedbackUseCase`

## Command contract

```swift
struct RequestAnalysisCommand: Sendable {
    let fixtureKey: FixtureKey
    let requestedLocale: SupportedLocale
    let clientRequestID: UUID
    let acceptedDisclaimerVersion: String
}
```

Client never sends probabilities, prompt/model IDs, raw provider data, entitlement, quota balance or cache key. Backend derives these authoritatively.

## Mapping rules

- DTOs are `Decodable` and schema-versioned.
- Unknown enum values map to explicit `.unknown(rawValue)` and fail closed where eligibility is involved.
- Domain initializers enforce probability sums and temporal invariants.
- Presentation mappers produce localized strings; Domain never contains UI copy.
