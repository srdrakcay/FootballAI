# Remote Config and Localization Architecture

## Typed Remote Config

```swift
struct AppConfiguration: Sendable {
    let features: FeatureFlags
    let supportedLeagues: Set<CompetitionID>
    let planLimits: PlanLimits
    let copyVariants: CopyVariants
    let minimumSupportedVersion: SemanticVersion
}

protocol RemoteConfigurationService: Sendable {
    func bootstrap() async -> AppConfiguration
    func fetchAndActivate() async throws -> AppConfiguration
}
```

`FirebaseRemoteConfigurationService` performs fetch → decode → schema validation → allowlist/min-max clamp → atomic activation. It keeps compiled defaults and last-known-good in local storage. UI never reads Firebase keys directly.

Backend has an equivalent validated loader. Security/monetization decisions use backend configuration; client config controls presentation and early eligibility hints only. Model alias resolves through a server-side allowlist; arbitrary provider model names are rejected.

## Fetch policy

- Fetch at cold start after showing compiled defaults; refresh when returning foreground after minimum interval.
- Critical kill switches may use a shorter backend cache; do not depend on instant client propagation.
- Offline/fetch failure uses last-known-good, otherwise compiled safe defaults (`generation=false`).
- Config parsing is all-or-nothing and observable with redacted metrics.

## Localization services

```swift
enum SupportedLocale: String, Codable { case tr, en, es, fr }

protocol LocaleProvider: Sendable {
    var current: SupportedLocale { get async }
    func set(_ locale: SupportedLocale?) async
}

protocol LocalizedAnalysisRepository: Sendable {
    func artifact(analysisID: Analysis.ID, locale: SupportedLocale) async throws -> LocalizedRationale
}
```

- App locale preference overrides supported system locale; otherwise English fallback.
- String Catalog owns static copy and ICU-style plural behavior.
- Backend stores canonical numeric analysis separately from `locales/{locale}`.
- Missing localized rationale triggers an idempotent localization job or English fallback; it never invokes a new probabilistic analysis.
- Stable limitation/rationale codes allow client-localized short labels even if narrative fallback is English.

## Copy variant safety

Remote Config returns `control`, `benefit_history_v1`, etc. The client maps these to reviewed String Catalog keys. Unknown IDs map to `control`. Legal/disclaimer variant changes require approved version mapping and audit; no raw HTML/Markdown from Remote Config is rendered.
