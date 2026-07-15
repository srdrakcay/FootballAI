# Phase 1 — Localization and Content

## Supported locales

- Turkish `tr`
- English `en`
- Spanish `es`
- French `fr`

Fallback: exact locale → base language → English. Dates, decimals, percentages and pluralization use Foundation locale APIs; persisted values remain locale-neutral UTC/integers.

## Content ownership

- Static UI/accessibility/error/paywall/legal keys: String Catalog (`Localizable.xcstrings`), reviewed and shipped with the app.
- Approved short campaign/paywall copy variants: Remote Config returns a **variant ID**, not arbitrary executable/formatted content. App maps ID to local string keys.
- AI rationale: server localized artifact, with stable rationale codes and evidence refs; probabilities are copied from canonical result.
- Legal text: versioned hosted document plus bundled summary; Remote Config may select approved version/URL ID.

## Required keys (examples)

```text
analysis.title
analysis.generated_at
analysis.data_snapshot_at
analysis.probability_disclaimer
analysis.limitations.title
analysis.stale
analysis.failure.retry
quota.remaining
quota.exhausted
subscription.restore
account.delete
```

## Canonical disclaimer intent

Every analysis screen must convey, in professionally reviewed translations:

> This AI-generated analysis is based only on the displayed data and expresses probabilities, not a certain result or betting advice. Data may be incomplete or outdated.

Exact production translations require legal/localization review; they are not remotely improvised.

## QA

- Pseudolocalization, truncation, RTL resilience (future-proofing), VoiceOver and Dynamic Type.
- Snapshot tests for all four languages and small/large devices.
- Terminology glossary for Draw, Over/Under, Both Teams to Score, confidence and data availability.
- Locale switch does not regenerate or change numeric probabilities.
