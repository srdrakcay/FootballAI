# Security and Secrets

## Trust boundaries

The iOS app is untrusted. It may request operations but cannot choose provider payload, prompt, model, quota, entitlement, cache validity or state transitions. Cloud Functions verify Auth, App Check, input schema, authorization, rate limits and replay/idempotency before any side effect.

## Secret placement

- AI/provider API keys, webhook signing secrets and service credentials: Google Secret Manager, mounted/bound to the minimum required Cloud Function runtime.
- Firebase public client configuration is not a secret, but is environment-specific and protected by rules/App Check.
- No secrets in Remote Config, Firestore, source control, xcconfig committed to git, analytics, crash logs, prompts or error messages.
- Separate secrets per environment and provider; least-privilege IAM. Developers do not need raw production secret access.

## Rotation runbook

1. Create a new provider credential with least privilege; store as a **new Secret Manager version**.
2. Test in staging with synthetic health check and no secret logging.
3. Deploy Function revision referencing the new version or dual-secret resolver (`current` + `next`).
4. Shift production traffic gradually; monitor auth errors, latency, model validation and cost.
5. Revoke old credential only after all live revisions use the new one and rollback window closes.
6. Disable/delete old secret version according to retention policy; record owner, incident/change ticket, timestamps and evidence.
7. If compromise is suspected: set generation kill switch, revoke immediately, rotate, inspect audit/provider logs, invalidate affected sessions if relevant, notify security/legal, then restore service.

Remote Config may disable generation quickly but **cannot rotate a secret**. Rotation is a Secret Manager + deployment/provider action.

## Additional controls

- App Check enforcement after staged monitoring; DeviceCheck/App Attest provider as appropriate.
- Per uid/device/IP/token-bucket limits; stricter anonymous signup/generation controls.
- Callable payload max sizes and allowlisted fields; reject prompt-like extra fields.
- Provider webhook signature verification, timestamp tolerance and replay store.
- Firestore Rules emulator tests and deny-by-default rules.
- Structured logs with secret/PII redaction; access/audit logs and alerts.
- Dependency scanning, secret scanning, protected branches and separate deploy identities.
