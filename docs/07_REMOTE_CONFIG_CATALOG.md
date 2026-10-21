# Phase 1 — Remote Config Catalog

Remote Config stores only non-secret, validated operational configuration. Client values are hints; backend re-fetches/validates authoritative limits.

| Key | Type | Default | Guardrail / owner |
|---|---|---:|---|
| `feature_analysis_generation_enabled` | Bool | false | Global kill switch, backend enforced |
| `feature_cached_analysis_read_enabled` | Bool | true | Separate read switch |
| `feature_premium_enabled` | Bool | false | Release/commerce |
| `feature_extended_leagues_enabled` | Bool | false | Requires provider approval |
| `feature_notifications_enabled` | Bool | false | Future only; no V1 settings UI |
| `supported_leagues_v1` | JSON string array | core six | Allowlisted IDs only |
| `free_monthly_unique_views` | Int | 1 | Clamp 0...20; backend authoritative |
| `analysis_credit_cost` | Int | 1 | Clamp 1...100; credits charged per analysis; backend authoritative |
| `welcome_credits` | Int | 0 | Clamp 0...100; credits granted once when a new wallet is created; missing/invalid = 0 |
| `free_history_days` | Int | 30 | Clamp 1...90 |
| `premium_history_days` | Int | 365 | Clamp 30...730 |
| `analysis_ttl_policy_v1` | JSON | documented tiers | Schema validated; never past kickoff |
| `analysis_schema_version` | String | `2.0` | Deployed backend allowlist |
| `analysis_prompt_version` | String | `football-v2.1.0` | Deployed prompt registry only |
| `analysis_model_alias` | String | approved alias | Server maps alias to provider model |
| `analysis_max_retries` | Int | 2 | Clamp 0...3 |
| `analysis_lock_lease_seconds` | Int | 90 | Clamp 30...180 |
| `copy_paywall_variant` | String | `control` | App-known variant IDs |
| `copy_disclaimer_variant` | String | `legal_v1` | Approved local key/version only |
| `minimum_supported_app_version` | String | release value | SemVer validated |

## Explicit denylist

Never store API keys, provider tokens, service account JSON, webhook signing secrets, private prompt contents, encryption keys, admin URLs with credentials or user PII in Remote Config. “Obscured” or client-only parameters are still public.

## Rollout

Dev → staging → 5% production → 25% → 100%, with metric/rollback gates. Keep typed in-app defaults and last-known-good values. Invalid fetch is rejected atomically; unknown league/model/prompt IDs fall back safely. Changes are audited with owner, ticket, reason and expiry/review date.
