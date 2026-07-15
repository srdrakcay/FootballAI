# Phase 1 — Trust, Legal and Analytics

## Trust and safety

- Display data sources/categories, snapshot time, generation time, validity and missing inputs.
- Offer helpful/not helpful feedback and “misleading/incorrect” report.
- Do not display bookmaker odds, bet sizing, guaranteed returns or imperative wagering language.
- Calibrate confidence against backtests; confidence is not probability of “the whole analysis being correct”.
- Kill switch analysis generation independently from cached-read display.

## Legal/App Store deliverables

- Privacy Policy, Terms of Use, subscription/auto-renewal terms.
- Apple standard EULA or custom EULA decision.
- Account deletion in-app and server completion policy.
- App Privacy data inventory for Auth, analytics, crash, purchase and support data.
- AI-generated content disclosure and reporting path.
- Age rating and football/betting-adjacent positioning review by counsel.
- Support URL/contact, App Review notes, restore purchases and manage subscription.
- Provider licensing/attribution and model/provider data-processing terms.

This document is a product checklist, not legal advice.

## Core metrics

- Activation: fixture detail → first successful analysis.
- D1/D7/D30 retention and weekly matchday active users.
- Analysis success, validation failure, retry and latency distributions.
- Cache hit, stale rate, single-flight coalescing and cost per cache miss.
- Helpful rate, report rate and rationale/data-availability breakdown.
- Probability calibration: Brier/log loss by market, league and time-to-kickoff.
- Quota exhausted → paywall → purchase; restore, churn, refund/cancellation.
- Account link/deletion success.

## Event requirements

Events include `fixture_viewed`, `analysis_requested`, `analysis_cache_hit`, `analysis_ready`, `analysis_failed`, `analysis_retry`, `analysis_feedback`, `quota_exhausted`, `paywall_viewed`, `purchase_completed`, `purchase_failed`, `restore_completed`, `account_linked`, `account_deleted`.

Do not log prompts, raw squad data, secrets, email, free-form feedback or full model output in analytics. Use pseudonymous IDs and documented retention/consent rules.
