import { randomUUID } from "node:crypto";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import type { RequestAnalysisPayload } from "../shared/contracts.js";
import type { AuthorizedContext } from "../analysis/orchestrator.js";

const fixtureKeyPattern = /^[A-Za-z0-9._:-]{1,160}$/;
const supportedLocales = new Set(["tr", "en", "es", "fr"]);

export function authorize(request: CallableRequest<unknown>): AuthorizedContext {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "AUTH_REQUIRED");
  if (!request.app?.appId) throw new HttpsError("failed-precondition", "APP_CHECK_FAILED");
  return { uid: request.auth.uid, appId: request.app.appId, correlationId: randomUUID() };
}

export function parsePayload(value: unknown): RequestAnalysisPayload {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new HttpsError("invalid-argument", "INVALID_REQUEST");
  const data = value as Record<string, unknown>;
  const allowed = new Set(["fixtureKey", "locale", "clientRequestId", "acceptedDisclaimerVersion"]);
  if (Object.keys(data).some((key) => !allowed.has(key))) throw new HttpsError("invalid-argument", "UNKNOWN_REQUEST_FIELD");
  if (typeof data.fixtureKey !== "string" || !fixtureKeyPattern.test(data.fixtureKey)) throw new HttpsError("invalid-argument", "INVALID_FIXTURE_KEY");
  if (typeof data.locale !== "string" || !supportedLocales.has(data.locale)) throw new HttpsError("invalid-argument", "INVALID_LOCALE");
  if (typeof data.clientRequestId !== "string" || data.clientRequestId.length > 64) throw new HttpsError("invalid-argument", "INVALID_REQUEST_ID");
  if (typeof data.acceptedDisclaimerVersion !== "string" || data.acceptedDisclaimerVersion.length > 32) throw new HttpsError("invalid-argument", "INVALID_DISCLAIMER_VERSION");
  return data as unknown as RequestAnalysisPayload;
}
