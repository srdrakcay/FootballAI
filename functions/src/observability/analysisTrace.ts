import { createHash, randomUUID } from "node:crypto";
import * as logger from "firebase-functions/logger";
import { HttpsError } from "firebase-functions/v2/https";

/**
 * Structured, PII-free trace for one analysis call. Every line carries the same traceId, a hashed uid and
 * the fixture key, so a failure can be followed in Cloud Logging with:
 *   jsonPayload.traceId="..."   or   jsonPayload.op="requestAnalysis" severity>=WARNING
 */
export interface AnalysisTrace {
  readonly traceId: string;
  stage(stage: string, extra?: Record<string, unknown>): void;
  fail(error: unknown, stage?: string): void;
  done(extra?: Record<string, unknown>): void;
}

export function startAnalysisTrace(op: string, uid: string | undefined, fixtureKey: unknown): AnalysisTrace {
  const traceId = randomUUID();
  const startedAt = Date.now();
  const base = {
    op,
    traceId,
    uidHash: uid ? createHash("sha256").update(uid).digest("hex").slice(0, 10) : "anonymous",
    fixtureKey: typeof fixtureKey === "string" ? fixtureKey.slice(0, 80) : null,
  };
  let lastStage = "start";
  let failureLogged = false;
  const elapsed = () => ({ elapsedMs: Date.now() - startedAt });

  return {
    traceId,
    stage(stage, extra = {}) {
      lastStage = stage;
      logger.info(`analysis.${stage} op=${op} trace=${traceId.slice(0, 8)} ${Date.now() - startedAt}ms ${JSON.stringify(extra)}`, { ...base, stage, ...elapsed(), ...extra });
    },
    fail(error, stage) {
      if (failureLogged) return;
      failureLogged = true;
      const failedAt = stage ?? lastStage;
      const details = describeError(error);
      // Client-caused outcomes (not enough credits, ineligible fixture) are expected: warn, not error.
      const expected = error instanceof HttpsError && ["resource-exhausted", "failed-precondition", "invalid-argument", "not-found", "unauthenticated"].includes(error.code);
      (expected ? logger.warn : logger.error)(
        `analysis.failed op=${op} trace=${traceId.slice(0, 8)} stage=${failedAt} ${JSON.stringify(details)}`,
        { ...base, stage: failedAt, ...elapsed(), ...details },
      );
    },
    done(extra = {}) {
      logger.info(`analysis.done op=${op} trace=${traceId.slice(0, 8)} ${Date.now() - startedAt}ms`, { ...base, stage: "done", ...elapsed(), ...extra });
    },
  };
}

function describeError(error: unknown): Record<string, unknown> {
  if (error instanceof HttpsError) return { errorKind: "HttpsError", code: error.code, message: error.message.slice(0, 200) };
  if (error instanceof Error) {
    const fields = error as Error & { status?: number; retryable?: boolean; code?: unknown };
    return {
      errorKind: error.name,
      message: error.message.slice(0, 300),
      providerStatus: fields.status ?? null,
      retryable: fields.retryable ?? null,
      code: typeof fields.code === "string" || typeof fields.code === "number" ? fields.code : null,
      stack: error.stack?.split("\n").slice(0, 4).join(" | ").slice(0, 600),
    };
  }
  return { errorKind: typeof error, message: String(error).slice(0, 200) };
}
