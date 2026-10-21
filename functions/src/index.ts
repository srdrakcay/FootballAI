import { createHash, timingSafeEqual } from "node:crypto";
import { readFileSync } from "node:fs";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { onCall, onRequest, HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import { authorize, parsePayload } from "./security/requestGuard.js";
import { FootballDataClient } from "./fixtures/footballDataClient.js";
import { apiFootballKey, footballDataApiToken, geminiApiKey, requiredSecret, revenueCatWebhookAuthorization, rotatingSecret } from "./security/secrets.js";
import { analysisCreditCost, analysisRuntimeConfiguration, apiFootballSettings, welcomeCredits } from "./config/runtimeConfig.js";
import { parseRevenueCatCreditEvent } from "./revenuecat/creditEvent.js";
import { modelAliases } from "./config/providerRegistry.js";
import { AllowlistedModelAliasResolver } from "./analysis/modelGateway.js";
import { GeminiGateway, GeminiProviderError } from "./analysis/geminiGateway.js";
import { buildAnalysisSnapshot, fixtureInsights, type AnalysisSnapshot } from "./analysis/snapshotBuilder.js";
import { ensurePersonalLayer, loadAIProfile, publicAnalysis, type StructuredModel } from "./analysis/personalService.js";
import { AIProfileValidationError, parseAIProfile } from "./profile/aiProfile.js";
import { isSupportedLocale, resolveLocale, type SupportedLocale } from "./shared/locales.js";
import {
  applyStoreAdjustment, commitReservation, InsufficientCreditsError, ledgerEntry, newWallet,
  publicWallet, readWallet, release, reserve, spendDirect, type WalletState,
} from "./credits/wallet.js";
import { AnalysisResultValidator } from "./analysis/validator.js";
import { normalizeEvidenceRefs } from "./analysis/evidenceRefs.js";
import {
  ApiFootballError, fetchApiFootballDay, isUsableApiFootballFixture, normalizeApiFootballFixture, servedDates,
} from "./fixtures/apiFootball.js";
import { startAnalysisTrace, type AnalysisTrace } from "./observability/analysisTrace.js";

initializeApp();
setGlobalOptions({ region: "europe-west1", maxInstances: 10 });

const fixtureDatePattern = /^\d{4}-\d{2}-\d{2}$/;

interface FootballDataMatch {
  id: number;
  utcDate: string;
  status: string;
  lastUpdated?: string;
  competition: { id: number; code?: string | null; name: string };
  area?: { name?: string | null; code?: string | null };
  homeTeam: { id?: number | null; name?: string | null; shortName?: string | null };
  awayTeam: { id?: number | null; name?: string | null; shortName?: string | null };
}

interface FootballDataMatchList { matches?: FootballDataMatch[] }

export const bootstrapUser = onCall({ enforceAppCheck: true, timeoutSeconds: 10, invoker: "public" }, async (request) => {
  const context = authorize(request);
  const locale = resolveLocale(request.data?.locale);
  const db = getFirestore();
  const userReference = db.collection("users").doc(context.uid);
  const walletReference = userReference.collection("private").doc("wallet");
  const quotaReference = userReference.collection("private").doc("quota");

  const welcome = await welcomeCredits();
  const wallet = await db.runTransaction(async (transaction) => {
    const [user, walletSnapshot, quota] = await Promise.all([
      transaction.get(userReference), transaction.get(walletReference), transaction.get(quotaReference),
    ]);
    if (!user.exists) {
      transaction.create(userReference, {
        schemaVersion: 1,
        createdAt: FieldValue.serverTimestamp(),
        lastSeenAt: FieldValue.serverTimestamp(),
        authProviders: ["anonymous"],
        locale,
        deletionStatus: "active",
      });
    } else {
      transaction.set(userReference, { locale, lastSeenAt: FieldValue.serverTimestamp() }, { merge: true });
    }

    if (walletSnapshot.exists) return readWallet(walletSnapshot.data());
    const created = newWallet(quota.exists ? Number(quota.data()?.remaining ?? 0) : undefined, welcome);
    transaction.create(walletReference, { schemaVersion: 1, currency: "credits", ...created, updatedAt: FieldValue.serverTimestamp() });
    if (created.balance > 0) {
      transaction.create(userReference.collection("ledger").doc("welcome"), {
        ...ledgerEntry("welcome_grant", { ...created, balance: 0 }, created),
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    return created;
  });

  const [cost, profileSnapshot] = await Promise.all([
    analysisCreditCost(),
    userReference.collection("private").doc("aiProfile").get(),
  ]);
  return {
    uid: context.uid,
    wallet: publicWallet(wallet, cost),
    hasAIProfile: profileSnapshot.exists,
    aiProfile: profileSnapshot.exists ? await loadAIProfile(context.uid) : null,
    // Kept for app versions that read the flat fields.
    balance: wallet.balance,
    analysisCreditCost: cost,
  };
});

export const updateAIProfile = onCall({ enforceAppCheck: true, timeoutSeconds: 10, invoker: "public" }, async (request) => {
  const context = authorize(request);
  let profile;
  try {
    profile = parseAIProfile(request.data?.profile);
  } catch (error) {
    throw new HttpsError("invalid-argument", error instanceof AIProfileValidationError ? error.message : "INVALID_PROFILE");
  }
  const userReference = getFirestore().collection("users").doc(context.uid);
  const batch = getFirestore().batch();
  batch.set(userReference.collection("private").doc("aiProfile"), {
    schemaVersion: 1,
    ...profile,
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (isSupportedLocale(request.data?.locale)) {
    batch.set(userReference, { locale: request.data.locale, lastSeenAt: FieldValue.serverTimestamp() }, { merge: true });
  }
  await batch.commit();
  return { profile };
});

export const syncFixtures = onCall({
  enforceAppCheck: true,
  timeoutSeconds: 30,
  invoker: "public",
  secrets: [footballDataApiToken, apiFootballKey],
}, async (request) => {
  authorize(request);
  const { dateFrom, dateTo } = parseFixtureWindow(request.data);
  const db = getFirestore();
  // Browse-only leagues from the second provider; never allowed to fail or delay the main list.
  await refreshApiFootball(dateFrom, dateTo).catch((error) => {
    console.warn("api_football_sync_failed", { error: error instanceof Error ? error.message : "unknown", detail: error instanceof ApiFootballError ? error.detail : undefined });
  });
  const windowReference = db.collection("fixtureSyncWindows").doc(`${dateFrom}_${dateTo}`);
  const windowSnapshot = await windowReference.get();
  const fetchedAt = windowSnapshot.data()?.fetchedAt as Timestamp | undefined;
  if (fetchedAt && Date.now() - fetchedAt.toMillis() < 15 * 60 * 1_000) {
    const fixtures = await fixturesInWindow(dateFrom, dateTo);
    return { count: fixtures.length, cached: true, fixtures };
  }

  let matches: FootballDataMatch[];
  let remainingThisMinute: number | null = null;
  try {
    const client = new FootballDataClient({ token: await rotatingSecret("FOOTBALL_DATA_API_TOKEN") });
    const response = await client.getMatches<FootballDataMatchList>({ dateFrom, dateTo });
    matches = (response.data.matches ?? []).filter(validFootballDataMatch);
    remainingThisMinute = response.rateLimit.remainingThisMinute;
  } catch (error) {
    // Provider outage or rate limit: serve what we already have instead of failing the screen.
    console.warn("fixture_sync_provider_failed", { error: error instanceof Error ? error.message : "unknown" });
    const fixtures = await fixturesInWindow(dateFrom, dateTo);
    return { count: fixtures.length, cached: true, stale: true, fixtures };
  }

  for (let offset = 0; offset < matches.length; offset += 400) {
    const batch = db.batch();
    for (const match of matches.slice(offset, offset + 400)) {
      const reference = db.collection("fixtures").doc(`football-data:${match.id}`);
      batch.set(reference, normalizedFixture(match), { merge: true });
    }
    await batch.commit();
  }
  await windowReference.set({
    dateFrom,
    dateTo,
    count: matches.length,
    fetchedAt: FieldValue.serverTimestamp(),
    providerRemainingThisMinute: remainingThisMinute,
  });
  const browseOnly = (await fixturesInWindow(dateFrom, dateTo)).filter((fixture) => String(fixture.key).startsWith("api-football:"));
  const fixtures = [...matches.map((match) => publicFixture(`football-data:${match.id}`, normalizedFixture(match))), ...browseOnly];
  return { count: fixtures.length, cached: false, fixtures };
});

export const getFixtureInsights = onCall({
  enforceAppCheck: true,
  timeoutSeconds: 40,
  memory: "256MiB",
  invoker: "public",
  secrets: [footballDataApiToken],
}, async (request) => {
  authorize(request);
  const fixtureKey = typeof request.data?.fixtureKey === "string" ? request.data.fixtureKey.trim() : "";
  if (!fixtureKey || fixtureKey.length > 160) throw new HttpsError("invalid-argument", "INVALID_FIXTURE_KEY");

  const fixtureSnapshot = await getFirestore().collection("fixtures").doc(fixtureKey).get();
  if (!fixtureSnapshot.exists) throw new HttpsError("not-found", "FIXTURE_NOT_FOUND");
  if (fixtureSnapshot.data()?.analysisAvailable === false) throw new HttpsError("failed-precondition", "ANALYSIS_UNAVAILABLE_FOR_COMPETITION");

  const footballClient = new FootballDataClient({ token: await rotatingSecret("FOOTBALL_DATA_API_TOKEN") });
  const snapshot = await cachedOrFreshAnalysisSnapshot(fixtureKey, fixtureSnapshot.data() ?? {}, footballClient);
  return fixtureInsights(snapshot);
});

/** Opens an analysis the user already unlocked. Never charges. */
/** Runs a callable body under an analysis trace so every outcome (including thrown HttpsErrors) is logged once. */
async function withTrace<T>(op: string, request: CallableRequest, run: (trace: AnalysisTrace) => Promise<T>): Promise<T> {
  const trace = startAnalysisTrace(op, request.auth?.uid, request.data?.fixtureKey);
  trace.stage("start", { locale: typeof request.data?.locale === "string" ? request.data.locale : null });
  try {
    const result = await run(trace);
    trace.done();
    return result;
  } catch (error) {
    trace.fail(error);
    throw error;
  }
}

export const getAnalysis = onCall({
  enforceAppCheck: true,
  timeoutSeconds: 30,
  memory: "256MiB",
  invoker: "public",
  secrets: [geminiApiKey],
}, async (request) => withTrace("getAnalysis", request, async (trace) => {
  const context = authorize(request);
  const fixtureKey = typeof request.data?.fixtureKey === "string" ? request.data.fixtureKey.trim() : "";
  if (!/^[A-Za-z0-9._:-]{1,160}$/.test(fixtureKey)) throw new HttpsError("invalid-argument", "INVALID_FIXTURE_KEY");
  const locale = resolveLocale(request.data?.locale);
  const db = getFirestore();
  const fixtureHash = createHash("sha256").update(fixtureKey).digest("hex");
  const userReference = db.collection("users").doc(context.uid);
  const [history, wallet, cost] = await Promise.all([
    userReference.collection("history").doc(fixtureHash).get(),
    userReference.collection("private").doc("wallet").get(),
    analysisCreditCost(),
  ]);
  const walletView = publicWallet(readWallet(wallet.data()), cost);
  const analysisId = history.data()?.analysisId;
  trace.stage("history_checked", { unlocked: history.exists, balance: walletView.balance, creditCost: cost });
  if (!history.exists || typeof analysisId !== "string") return { state: "locked", wallet: walletView };
  return unlockedPayload(context.uid, fixtureKey, fixtureHash, analysisId, locale, context.correlationId, `history_${fixtureHash.slice(0, 24)}`, walletView);
}));

/** Unlocks (and if needed generates) the analysis for a fixture. Charges once per user and fixture. */
export const requestAnalysis = onCall({
  enforceAppCheck: true,
  timeoutSeconds: 120,
  memory: "512MiB",
  invoker: "public",
  secrets: [geminiApiKey, footballDataApiToken],
}, async (request) => withTrace("requestAnalysis", request, async (trace) => {
  const context = authorize(request);
  const payload = parsePayload(request.data);
  const locale = resolveLocale(payload.locale);
  const fixtureHash = createHash("sha256").update(payload.fixtureKey).digest("hex");
  const reused = await reuseReadyAnalysis(context.uid, payload.fixtureKey);
  trace.stage("reuse_checked", { reused: Boolean(reused) });
  if (reused) {
    return unlockedPayload(context.uid, payload.fixtureKey, fixtureHash, reused.analysisId, locale, context.correlationId, reused.requestId);
  }

  const runtime = await analysisRuntimeConfiguration();
  trace.stage("config_loaded", { generationEnabled: runtime.featureAnalysisGenerationEnabled, model: runtime.modelAlias, promptVersion: runtime.promptVersion });
  if (!runtime.featureAnalysisGenerationEnabled) throw new HttpsError("failed-precondition", "CONFIG_UNAVAILABLE");
  const resolvedModel = new AllowlistedModelAliasResolver(modelAliases).resolve(runtime.modelAlias);
  if (resolvedModel.provider !== "google") throw new HttpsError("failed-precondition", "CONFIG_UNAVAILABLE");

  const db = getFirestore();
  const fixtureReference = db.collection("fixtures").doc(payload.fixtureKey);
  const fixtureSnapshot = await fixtureReference.get();
  if (!fixtureSnapshot.exists) throw new HttpsError("not-found", "FIXTURE_NOT_FOUND");
  // Browse-only fixtures have no form/standings data: refuse before any credit is reserved.
  if (fixtureSnapshot.data()?.analysisAvailable === false) throw new HttpsError("failed-precondition", "ANALYSIS_UNAVAILABLE_FOR_COMPETITION");
  trace.stage("fixture_loaded");
  const fixture = fixtureSnapshot.data() ?? {};
  const requestId = `req_${createHash("sha256").update(`${context.uid}\u001f${payload.clientRequestId}`).digest("hex").slice(0, 40)}`;
  const reservationId = `res_${createHash("sha256").update(`${context.uid}\u001f${fixtureHash}`).digest("hex")}`;
  const creditCost = await analysisCreditCost();
  const reservation = await reserveAnalysisCredits(context.uid, payload.fixtureKey, fixtureHash, requestId, reservationId, creditCost);
  trace.stage("credits_reserved", { creditCost, alreadyUnlocked: Boolean(reservation.historyAnalysisId) });
  if (reservation.historyAnalysisId) {
    return unlockedPayload(context.uid, payload.fixtureKey, fixtureHash, reservation.historyAnalysisId, locale, context.correlationId, `history_${fixtureHash.slice(0, 24)}`);
  }

  const requestReference = db.collection("analysisRequests").doc(requestId);
  await requestReference.set({
    schemaVersion: 1,
    uid: context.uid,
    fixtureKey: payload.fixtureKey,
    state: "generating",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  let analysisId: string;
  try {
    const footballClient = new FootballDataClient({ token: await rotatingSecret("FOOTBALL_DATA_API_TOKEN") });
    const snapshot = await cachedOrFreshAnalysisSnapshot(payload.fixtureKey, fixture, footballClient);
    const kickoffAt = new Date(snapshot.fixture.kickoffAt);
    if (kickoffAt.getTime() <= Date.now() + 5 * 60_000) throw new HttpsError("failed-precondition", "FIXTURE_INELIGIBLE");
    const availableSections = Object.values(snapshot.sections).filter((section) => section.status === "available").length;
    trace.stage("snapshot_ready", { availableSections, kickoffAt: snapshot.fixture.kickoffAt });
    if (availableSections < 1) throw new HttpsError("failed-precondition", "DATA_INSUFFICIENT");

    const generatedAt = new Date();
    const validUntil = new Date(Math.min(kickoffAt.getTime() - 60_000, generatedAt.getTime() + analysisTTLSeconds(kickoffAt, generatedAt) * 1_000));
    analysisId = `ana_${createHash("sha256").update(`${snapshot.contentHash}\u001f${runtime.modelAlias}\u001f${runtime.promptVersion}`).digest("hex")}`;
    const outputIdentity = {
      schemaVersion: runtime.schemaVersion,
      analysisId,
      status: "ready",
      fixtureKey: payload.fixtureKey,
      fixtureVersion: snapshot.fixture.fixtureVersion,
      snapshotId: snapshot.snapshotId,
      snapshotVersion: snapshot.snapshotVersion,
      generatedAt: generatedAt.toISOString(),
      validUntil: validUntil.toISOString(),
      promptVersion: runtime.promptVersion,
      modelVersion: runtime.modelAlias,
      // The shared layer is language-neutral; every reader's own language lives in the personal layer.
      language: "en",
    };

    await requestReference.set({ state: "validating", updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    trace.stage("model_call", { model: resolvedModel.model });
    const gateway = new GeminiGateway({
      apiKey: await rotatingSecret("GEMINI_API_KEY"),
      model: resolvedModel.model,
      responseSchema: analysisResultSchema(),
    });
    const generated = await gateway.generate({
      modelAlias: runtime.modelAlias,
      promptVersion: runtime.promptVersion,
      schemaVersion: runtime.schemaVersion,
      snapshot: { ...snapshot, outputIdentity },
      timeoutMs: 55_000,
      correlationId: context.correlationId,
    });
    trace.stage("model_done", { inputTokens: generated.inputTokens ?? null, outputTokens: generated.outputTokens ?? null });
    const validation = new AnalysisResultValidator().validate(normalizeEvidenceRefs(generated.rawJson), snapshot, {
      schemaVersion: runtime.schemaVersion,
      fixtureKey: payload.fixtureKey,
      fixtureVersion: snapshot.fixture.fixtureVersion,
      snapshotId: snapshot.snapshotId,
      snapshotVersion: snapshot.snapshotVersion,
      promptVersion: runtime.promptVersion,
      modelVersion: runtime.modelAlias,
    });
    if (!validation.ok) {
      console.warn("analysis_validation_failed", {
        correlationId: context.correlationId,
        issueCodes: [...new Set(validation.issues.map((issue) => issue.code))],
      });
      // Which field broke which rule, plus the head of the model output, so the cause is visible in Cloud Logging.
      trace.stage("validation_failed", {
        issues: validation.issues.slice(0, 10).map((issue) => `${issue.code} ${issue.path} ${issue.detail ?? ""}`.trim()),
        rawPreview: JSON.stringify(generated.rawJson).slice(0, 400),
        evidenceRefs: (generated.rawJson as { rationale?: Array<{ evidenceRefs?: unknown }> } | null)?.rationale?.map((item) => item.evidenceRefs),
      });
      throw new HttpsError("internal", "ANALYSIS_VALIDATION_FAILED");
    }

    trace.stage("validated");
    const analysis = validation.value as unknown as Record<string, unknown>;
    await persistReadyAnalysis(payload.fixtureKey, fixtureHash, analysisId, analysis, generated);
    await finalizeAnalysisCredits(context.uid, fixtureHash, { ...fixture, fixtureKey: payload.fixtureKey }, analysisId, analysis, reservationId, creditCost);
    await requestReference.set({
      state: "ready",
      analysisId,
      providerRequestId: generated.providerRequestId,
      inputTokens: generated.inputTokens ?? null,
      outputTokens: generated.outputTokens ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (error) {
    trace.fail(error);
    await releaseAnalysisReservation(context.uid, reservationId, creditCost);
    trace.stage("credits_released", { creditCost });
    await requestReference.set({
      state: error instanceof GeminiProviderError && error.retryable ? "failed_retryable" : "failed_permanent",
      errorCode: publicAnalysisErrorCode(error),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true }).catch(() => undefined);
    if (error instanceof HttpsError) throw error;
    if (error instanceof GeminiProviderError && error.status === 429) throw new HttpsError("resource-exhausted", "MODEL_RATE_LIMITED");
    console.error("analysis_generation_failed", {
      correlationId: context.correlationId,
      code: publicAnalysisErrorCode(error),
    });
    throw new HttpsError("unavailable", "ANALYSIS_GENERATION_FAILED");
  }
  return unlockedPayload(context.uid, payload.fixtureKey, fixtureHash, analysisId, locale, context.correlationId, requestId);
}));

async function unlockedPayload(
  uid: string,
  fixtureKey: string,
  fixtureHash: string,
  analysisId: string,
  locale: SupportedLocale,
  correlationId: string,
  requestId: string,
  knownWallet?: ReturnType<typeof publicWallet>,
): Promise<Record<string, unknown>> {
  const db = getFirestore();
  const [analysisSnapshot, fixtureSnapshot, walletSnapshot, cost] = await Promise.all([
    db.collection("analyses").doc(analysisId).get(),
    db.collection("fixtures").doc(fixtureKey).get(),
    knownWallet ? Promise.resolve(null) : db.collection("users").doc(uid).collection("private").doc("wallet").get(),
    knownWallet ? Promise.resolve(knownWallet.analysisCreditCost) : analysisCreditCost(),
  ]);
  if (!analysisSnapshot.exists) throw new HttpsError("not-found", "ANALYSIS_NOT_FOUND");
  const analysis = analysisSnapshot.data() ?? {};
  const personal = await ensurePersonalLayer({
    uid,
    fixtureKey,
    fixtureHash,
    locale,
    analysis,
    analysisId,
    fixture: fixtureSnapshot.data() ?? {},
    correlationId,
    model: personalModel,
  });
  return {
    requestId,
    analysisId,
    state: "ready",
    analysis: publicAnalysis(analysisId, analysis),
    personal,
    wallet: knownWallet ?? publicWallet(readWallet(walletSnapshot?.data()), cost),
  };
}

async function personalModel(): Promise<StructuredModel | null> {
  const runtime = await analysisRuntimeConfiguration().catch(() => null);
  if (!runtime) return null;
  const resolved = new AllowlistedModelAliasResolver(modelAliases).resolve(runtime.modelAlias);
  if (resolved.provider !== "google") return null;
  return new GeminiGateway({ apiKey: await rotatingSecret("GEMINI_API_KEY"), model: resolved.model, responseSchema: {} });
}

export const revenueCatWebhook = onRequest({
  timeoutSeconds: 15,
  invoker: "public",
  secrets: [revenueCatWebhookAuthorization],
  cors: false,
}, async (request, response) => {
  if (request.method !== "POST") {
    response.set("Allow", "POST").status(405).send("METHOD_NOT_ALLOWED");
    return;
  }
  if (!secureStringEqual(request.get("authorization") ?? "", requiredSecret(revenueCatWebhookAuthorization))) {
    response.status(401).send("UNAUTHORIZED");
    return;
  }

  let event;
  try {
    event = parseRevenueCatCreditEvent(request.body);
  } catch (error) {
    console.warn("revenuecat_webhook_invalid", { reason: error instanceof Error ? error.message : "UNKNOWN" });
    response.status(400).send("INVALID_EVENT");
    return;
  }
  if (!event) {
    response.status(200).json({ accepted: true, ignored: true });
    return;
  }
  if (event.creditDelta === 0) {
    response.status(200).json({ accepted: true, ignored: true, reason: "NO_CRD_ADJUSTMENT" });
    return;
  }

  try {
    await getAuth().getUser(event.uid);
  } catch {
    response.status(409).send("APP_USER_NOT_READY");
    return;
  }

  const db = getFirestore();
  const eventReference = db.collection("revenueCatEvents").doc(event.eventId);
  const walletReference = db.collection("users").doc(event.uid).collection("private").doc("wallet");
  const ledgerReference = db.collection("users").doc(event.uid).collection("ledger").doc(`rc_${createHash("sha256").update(event.eventId).digest("hex").slice(0, 40)}`);
  const processed = await db.runTransaction(async (transaction) => {
    const [existingEvent, walletSnapshot] = await Promise.all([
      transaction.get(eventReference),
      transaction.get(walletReference),
    ]);
    if (existingEvent.exists) return false;

    const before = readWallet(walletSnapshot.data());
    const after = applyStoreAdjustment(before, event.creditDelta);
    transaction.set(walletReference, {
      schemaVersion: 1,
      currency: "credits",
      ...after,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    transaction.create(ledgerReference, {
      ...ledgerEntry(event.creditDelta > 0 ? "purchase" : "refund", before, after, { productId: event.productId }),
      storeDelta: event.creditDelta,
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.create(eventReference, {
      schemaVersion: 1,
      uid: event.uid,
      type: "VIRTUAL_CURRENCY_TRANSACTION",
      currencyCode: "CRD",
      creditDelta: event.creditDelta,
      productId: event.productId,
      transactionId: event.transactionId,
      environment: event.environment,
      occurredAt: Timestamp.fromMillis(event.occurredAtMs),
      processedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });

  response.status(200).json({ accepted: true, duplicate: !processed });
});

export const deleteAccount = onCall({ enforceAppCheck: true, timeoutSeconds: 60, invoker: "public" }, async (request) => {
  const context = authorize(request);
  if (request.data?.confirmation !== "DELETE" || Object.keys(request.data ?? {}).some((key) => key !== "confirmation")) {
    throw new HttpsError("invalid-argument", "DELETE_CONFIRMATION_REQUIRED");
  }
  const db = getFirestore();
  const ownedCollections = ["analysisRequests", "usageLedger", "quotaReservations", "feedback", "subscriptions", "revenueCatEvents"];
  for (const collection of ownedCollections) {
    const snapshot = await db.collection(collection).where("uid", "==", context.uid).get();
    for (let offset = 0; offset < snapshot.docs.length; offset += 400) {
      const batch = db.batch();
      for (const document of snapshot.docs.slice(offset, offset + 400)) batch.delete(document.ref);
      await batch.commit();
    }
  }
  await db.collection("subscriptions").doc(context.uid).delete().catch(() => undefined);
  await db.recursiveDelete(db.collection("users").doc(context.uid));
  await getAuth().deleteUser(context.uid);
  console.info("account_deleted", { correlationId: context.correlationId });
  return { deleted: true };
});

function secureStringEqual(received: string, expected: string): boolean {
  const receivedBytes = Buffer.from(received);
  const expectedBytes = Buffer.from(expected);
  return receivedBytes.length === expectedBytes.length && timingSafeEqual(receivedBytes, expectedBytes);
}

function parseFixtureWindow(value: unknown): { dateFrom: string; dateTo: string } {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new HttpsError("invalid-argument", "INVALID_FIXTURE_WINDOW");
  const data = value as Record<string, unknown>;
  if (Object.keys(data).some((key) => key !== "dateFrom" && key !== "dateTo")) throw new HttpsError("invalid-argument", "UNKNOWN_REQUEST_FIELD");
  if (typeof data.dateFrom !== "string" || typeof data.dateTo !== "string" || !fixtureDatePattern.test(data.dateFrom) || !fixtureDatePattern.test(data.dateTo)) {
    throw new HttpsError("invalid-argument", "INVALID_FIXTURE_DATE");
  }
  const from = Date.parse(`${data.dateFrom}T00:00:00Z`);
  const to = Date.parse(`${data.dateTo}T00:00:00Z`);
  if (!Number.isFinite(from) || !Number.isFinite(to) || to <= from || to - from > 4 * 86_400_000) {
    throw new HttpsError("invalid-argument", "INVALID_FIXTURE_RANGE");
  }
  return { dateFrom: data.dateFrom, dateTo: data.dateTo };
}

function validFootballDataMatch(match: FootballDataMatch): boolean {
  return Number.isSafeInteger(match.id) && match.id > 0 && Number.isFinite(Date.parse(match.utcDate))
    && Boolean(match.competition?.name) && Boolean(match.homeTeam?.name ?? match.homeTeam?.shortName)
    && Boolean(match.awayTeam?.name ?? match.awayTeam?.shortName);
}

function normalizedFixture(match: FootballDataMatch): Record<string, unknown> {
  const homeName = match.homeTeam.name ?? match.homeTeam.shortName ?? "Home";
  const awayName = match.awayTeam.name ?? match.awayTeam.shortName ?? "Away";
  return {
    source: "football-data.org",
    sourceMatchId: match.id,
    fixtureVersion: 1,
    competitionId: match.competition.code ?? String(match.competition.id),
    competitionName: match.competition.name,
    competitionAreaName: match.area?.name ?? null,
    competitionAreaCode: match.area?.code ?? null,
    homeTeam: { id: String(match.homeTeam.id ?? `home-${match.id}`), name: homeName },
    awayTeam: { id: String(match.awayTeam.id ?? `away-${match.id}`), name: awayName },
    kickoffAt: Timestamp.fromDate(new Date(match.utcDate)),
    status: fixtureStatus(match.status),
    latestSnapshotId: null,
    providerUpdatedAt: match.lastUpdated ? Timestamp.fromDate(new Date(match.lastUpdated)) : null,
    syncedAt: FieldValue.serverTimestamp(),
  };
}

function fixtureStatus(value: string): string {
  switch (value.toUpperCase()) {
    case "TIMED": return "timed";
    case "SCHEDULED": return "scheduled";
    case "POSTPONED": return "postponed";
    case "SUSPENDED": return "suspended";
    case "CANCELLED": return "cancelled";
    case "IN_PLAY": case "PAUSED": case "LIVE": return "in_progress";
    case "AWARDED": return "awarded";
    case "FINISHED": return "finished";
    default: return "scheduled";
  }
}

async function cachedOrFreshAnalysisSnapshot(
  fixtureKey: string,
  fixture: Record<string, unknown>,
  client: FootballDataClient,
): Promise<AnalysisSnapshot> {
  const db = getFirestore();
  const fixtureReference = db.collection("fixtures").doc(fixtureKey);
  const snapshotReference = fixtureReference.collection("snapshots").doc("analysis-current-v1");
  const cached = await snapshotReference.get();
  const cachedData = cached.data() as (AnalysisSnapshot & { cachedAt?: Timestamp }) | undefined;
  if (cachedData?.cachedAt && Date.now() - cachedData.cachedAt.toMillis() < 30 * 60_000) {
    const { cachedAt: _, ...snapshot } = cachedData;
    return snapshot;
  }

  const snapshot = await buildAnalysisSnapshot(fixtureKey, fixture, client);
  await snapshotReference.set({ ...snapshot, cachedAt: FieldValue.serverTimestamp() });
  await fixtureReference.set({
    latestSnapshotId: snapshot.snapshotId,
    latestSnapshotAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  return snapshot;
}

async function reserveAnalysisCredits(
  uid: string,
  fixtureKey: string,
  fixtureHash: string,
  requestId: string,
  reservationId: string,
  creditCost: number,
): Promise<{ historyAnalysisId?: string }> {
  const db = getFirestore();
  const userReference = db.collection("users").doc(uid);
  const walletReference = userReference.collection("private").doc("wallet");
  const historyReference = userReference.collection("history").doc(fixtureHash);
  const reservationReference = db.collection("quotaReservations").doc(reservationId);
  return db.runTransaction(async (transaction) => {
    const [walletSnapshot, history, existingReservation] = await Promise.all([
      transaction.get(walletReference),
      transaction.get(historyReference),
      transaction.get(reservationReference),
    ]);
    if (history.exists) {
      const analysisId = history.data()?.analysisId;
      return typeof analysisId === "string" ? { historyAnalysisId: analysisId } : {};
    }
    if (!walletSnapshot.exists) throw new HttpsError("failed-precondition", "WALLET_UNAVAILABLE");

    let wallet = readWallet(walletSnapshot.data());
    const prior = existingReservation.data();
    if (existingReservation.exists && prior?.state === "reserved") {
      const expiresAt = prior.expiresAt as Timestamp | undefined;
      if (expiresAt && expiresAt.toMillis() > Date.now()) throw new HttpsError("aborted", "ANALYSIS_ALREADY_IN_PROGRESS");
      // A crashed generation left a stale hold; give it back before reserving again.
      wallet = release(wallet, Number(prior.creditCost ?? creditCost));
    }

    try {
      wallet = reserve(wallet, creditCost);
    } catch (error) {
      if (error instanceof InsufficientCreditsError) throw insufficientCredits(error);
      throw error;
    }

    transaction.update(walletReference, { reservedCredits: wallet.reservedCredits, updatedAt: FieldValue.serverTimestamp() });
    transaction.set(reservationReference, {
      schemaVersion: 1,
      uid,
      fixtureKey,
      fixtureHash,
      requestId,
      creditCost,
      state: "reserved",
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 3 * 60_000),
    });
    return {};
  });
}

function insufficientCredits(error: InsufficientCreditsError): HttpsError {
  return new HttpsError("resource-exhausted", "INSUFFICIENT_CREDITS", {
    reason: "INSUFFICIENT_CREDITS",
    balance: error.available,
    requiredCredits: error.required,
  });
}

async function releaseAnalysisReservation(uid: string, reservationId: string, fallbackCreditCost: number): Promise<void> {
  const db = getFirestore();
  const reservationReference = db.collection("quotaReservations").doc(reservationId);
  const walletReference = db.collection("users").doc(uid).collection("private").doc("wallet");
  await db.runTransaction(async (transaction) => {
    const [reservation, walletSnapshot] = await Promise.all([
      transaction.get(reservationReference),
      transaction.get(walletReference),
    ]);
    if (!reservation.exists || reservation.data()?.state !== "reserved") return;
    if (walletSnapshot.exists) {
      const wallet = release(readWallet(walletSnapshot.data()), Number(reservation.data()?.creditCost ?? fallbackCreditCost));
      transaction.update(walletReference, { reservedCredits: wallet.reservedCredits, updatedAt: FieldValue.serverTimestamp() });
    }
    transaction.set(reservationReference, { state: "released", releasedAt: FieldValue.serverTimestamp() }, { merge: true });
  }).catch((error: unknown) => {
    console.error("reservation_release_failed", { error: error instanceof Error ? error.message : "unknown" });
  });
}

async function finalizeAnalysisCredits(
  uid: string,
  fixtureHash: string,
  fixture: Record<string, unknown>,
  analysisId: string,
  analysis: Record<string, unknown>,
  reservationId: string,
  creditCost: number,
): Promise<void> {
  const db = getFirestore();
  const userReference = db.collection("users").doc(uid);
  const walletReference = userReference.collection("private").doc("wallet");
  const historyReference = userReference.collection("history").doc(fixtureHash);
  const reservationReference = db.collection("quotaReservations").doc(reservationId);
  const ledgerReference = userReference.collection("ledger").doc(`unlock_${fixtureHash.slice(0, 40)}`);
  await db.runTransaction(async (transaction) => {
    const [walletSnapshot, history, reservation] = await Promise.all([
      transaction.get(walletReference),
      transaction.get(historyReference),
      transaction.get(reservationReference),
    ]);
    const reserved = reservation.exists && reservation.data()?.state === "reserved";
    if (history.exists) {
      if (reserved) {
        const wallet = release(readWallet(walletSnapshot.data()), creditCost);
        transaction.update(walletReference, { reservedCredits: wallet.reservedCredits, updatedAt: FieldValue.serverTimestamp() });
        transaction.set(reservationReference, { state: "released", releasedAt: FieldValue.serverTimestamp() }, { merge: true });
      }
      return;
    }
    if (!walletSnapshot.exists || !reserved) throw new HttpsError("failed-precondition", "RESERVATION_UNAVAILABLE");
    const before = readWallet(walletSnapshot.data());
    let after: WalletState;
    try {
      after = commitReservation(before, creditCost);
    } catch (error) {
      if (error instanceof InsufficientCreditsError) throw insufficientCredits(error);
      throw error;
    }
    writeUnlock(transaction, walletReference, historyReference, ledgerReference, before, after, fixtureHash, fixture, analysisId, analysis, creditCost);
    transaction.set(reservationReference, { state: "committed", committedAt: FieldValue.serverTimestamp() }, { merge: true });
  });
}

function writeUnlock(
  transaction: FirebaseFirestore.Transaction,
  walletReference: FirebaseFirestore.DocumentReference,
  historyReference: FirebaseFirestore.DocumentReference,
  ledgerReference: FirebaseFirestore.DocumentReference,
  before: WalletState,
  after: WalletState,
  fixtureHash: string,
  fixture: Record<string, unknown>,
  analysisId: string,
  analysis: Record<string, unknown>,
  creditCost: number,
): void {
  transaction.update(walletReference, {
    balance: after.balance,
    reservedCredits: after.reservedCredits,
    lifetimeSpent: after.lifetimeSpent,
    updatedAt: FieldValue.serverTimestamp(),
  });
  const history = analysisHistoryData(fixtureHash, fixture, analysisId, analysis, creditCost);
  transaction.create(historyReference, history);
  transaction.create(ledgerReference, {
    ...ledgerEntry("analysis_unlock", before, after, {
      fixtureKey: String(history.fixtureKey),
      analysisId,
      label: `${String(history.homeTeamName)} – ${String(history.awayTeamName)}`,
    }),
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function persistReadyAnalysis(
  fixtureKey: string,
  fixtureHash: string,
  analysisId: string,
  analysis: Record<string, unknown>,
  generated: { providerRequestId: string; inputTokens?: number; outputTokens?: number },
): Promise<void> {
  const db = getFirestore();
  const reference = db.collection("analyses").doc(analysisId);
  const generatedAt = Timestamp.fromDate(new Date(String(analysis.generatedAt)));
  const validUntil = Timestamp.fromDate(new Date(String(analysis.validUntil)));
  const batch = db.batch();
  batch.set(reference, {
    ...analysis,
    fixtureKey,
    state: "ready",
    markets: analysis.markets,
    canonicalMarkets: analysis.markets,
    generatedAt,
    validUntil,
    providerRequestId: generated.providerRequestId,
    inputTokens: generated.inputTokens ?? null,
    outputTokens: generated.outputTokens ?? null,
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.set(reference.collection("locales").doc(String(analysis.language)), {
    language: analysis.language,
    rationale: analysis.rationale ?? [],
    limitations: analysis.limitations ?? [],
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.set(db.collection("analysisByFixture").doc(fixtureHash), {
    fixtureKey,
    analysisId,
    state: "ready",
    validUntil,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
}

function analysisHistoryData(
  fixtureHash: string,
  fixture: Record<string, unknown>,
  analysisId: string,
  analysis: Record<string, unknown>,
  creditCost: number,
): Record<string, unknown> {
  const markets = (analysis.markets ?? analysis.canonicalMarkets) as Record<string, unknown> | undefined;
  const matchResult = markets?.matchResult as Record<string, unknown> | undefined;
  const home = fixture.homeTeam as Record<string, unknown> | undefined;
  const away = fixture.awayTeam as Record<string, unknown> | undefined;
  return {
    schemaVersion: 2,
    fixtureKey: fixture.fixtureKey ?? analysis.fixtureKey ?? fixtureHash,
    analysisId,
    competitionId: fixture.competitionId ?? null,
    competitionName: fixture.competitionName ?? fixture.competitionId ?? "Football",
    homeTeamId: home?.id ?? null,
    homeTeamName: home?.name ?? "Home",
    awayTeamId: away?.id ?? null,
    awayTeamName: away?.name ?? "Away",
    kickoffAt: fixture.kickoffAt,
    viewedAt: FieldValue.serverTimestamp(),
    generatedAt: timestampValue(analysis.generatedAt),
    validUntil: timestampValue(analysis.validUntil),
    homeWinProbability: matchResult?.homePct ?? null,
    drawProbability: matchResult?.drawPct ?? null,
    awayWinProbability: matchResult?.awayPct ?? null,
    creditCost,
  };
}

function timestampValue(value: unknown): Timestamp {
  if (value instanceof Timestamp) return value;
  return Timestamp.fromDate(new Date(String(value)));
}

let cachedAnalysisResultSchema: Record<string, unknown> | undefined;
function analysisResultSchema(): Record<string, unknown> {
  if (cachedAnalysisResultSchema) return cachedAnalysisResultSchema;
  const url = new URL("../../generated-schemas/analysis-result.schema.json", import.meta.url);
  cachedAnalysisResultSchema = JSON.parse(readFileSync(url, "utf8")) as Record<string, unknown>;
  return cachedAnalysisResultSchema;
}

function analysisTTLSeconds(kickoffAt: Date, generatedAt: Date): number {
  const untilKickoff = kickoffAt.getTime() - generatedAt.getTime();
  if (untilKickoff > 48 * 3_600_000) return 86_400;
  if (untilKickoff > 6 * 3_600_000) return 21_600;
  return 3_600;
}

function publicAnalysisErrorCode(error: unknown): string {
  if (error instanceof HttpsError) return error.message.slice(0, 64);
  if (error instanceof GeminiProviderError) return error.message;
  if (error instanceof Error) return error.message.slice(0, 64);
  return "UNKNOWN";
}

async function reuseReadyAnalysis(uid: string, fixtureKey: string): Promise<{ requestId: string; analysisId: string; state: "ready" } | null> {
  const db = getFirestore();
  const fixtureHash = createHash("sha256").update(fixtureKey).digest("hex");
  const pointerReference = db.collection("analysisByFixture").doc(fixtureHash);
  let analysisId = (await pointerReference.get()).data()?.analysisId as string | undefined;
  let analysisReference = analysisId ? db.collection("analyses").doc(analysisId) : null;
  let analysisSnapshot = analysisReference ? await analysisReference.get() : null;

  if (!analysisSnapshot?.exists || analysisSnapshot.data()?.state !== "ready") {
    const ready = await db.collection("analyses").where("fixtureKey", "==", fixtureKey).where("state", "==", "ready").limit(1).get();
    analysisSnapshot = ready.docs[0] ?? null;
    if (!analysisSnapshot) return null;
    analysisId = analysisSnapshot.id;
    analysisReference = analysisSnapshot.ref;
    await pointerReference.set({ fixtureKey, analysisId, state: "ready", updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  }

  const analysis = analysisSnapshot.data();
  const validUntil = analysis?.validUntil as Timestamp | undefined;
  const generatedAt = analysis?.generatedAt as Timestamp | undefined;
  if (!analysisId || !analysisReference || !validUntil || !generatedAt || validUntil.toMillis() <= Date.now()) return null;
  const fixtureSnapshot = await db.collection("fixtures").doc(fixtureKey).get();
  if (!fixtureSnapshot.exists) throw new HttpsError("not-found", "FIXTURE_NOT_FOUND");
  await commitHistoryAndCredits(uid, fixtureKey, fixtureHash, fixtureSnapshot.data() ?? {}, analysisId, analysis ?? {}, await analysisCreditCost());
  return { requestId: `reused_${fixtureHash.slice(0, 24)}`, analysisId, state: "ready" };
}

async function commitHistoryAndCredits(uid: string, fixtureKey: string, fixtureHash: string, fixture: Record<string, unknown>, analysisId: string, analysis: Record<string, unknown>, creditCost: number): Promise<void> {
  const db = getFirestore();
  const userReference = db.collection("users").doc(uid);
  const historyReference = userReference.collection("history").doc(fixtureHash);
  const walletReference = userReference.collection("private").doc("wallet");
  const ledgerReference = userReference.collection("ledger").doc(`unlock_${fixtureHash.slice(0, 40)}`);
  await db.runTransaction(async (transaction) => {
    const [history, walletSnapshot] = await Promise.all([transaction.get(historyReference), transaction.get(walletReference)]);
    if (history.exists) return;
    if (!walletSnapshot.exists) throw new HttpsError("failed-precondition", "WALLET_UNAVAILABLE");
    const before = readWallet(walletSnapshot.data());
    let after: WalletState;
    try {
      after = spendDirect(before, creditCost);
    } catch (error) {
      if (error instanceof InsufficientCreditsError) throw insufficientCredits(error);
      throw error;
    }
    writeUnlock(transaction, walletReference, historyReference, ledgerReference, before, after, fixtureHash, { ...fixture, fixtureKey }, analysisId, analysis, creditCost);
  });
}

/** Pulls the days the provider's free plan serves (at most 3), 60-minute cache per date, one call per date. */
async function refreshApiFootball(dateFrom: string, dateTo: string): Promise<void> {
  const settings = await apiFootballSettings();
  if (!settings.enabled) return;
  const dates = servedDates(dateFrom, dateTo);
  if (dates.length === 0) return;
  const db = getFirestore();
  const allowed = new Set(settings.leagueIds);
  const key = await rotatingSecret("API_FOOTBALL_KEY");
  for (const date of dates) {
    const marker = db.collection("fixtureSyncWindows").doc(`af_${date}`);
    const fetchedAt = (await marker.get()).data()?.fetchedAt as Timestamp | undefined;
    if (fetchedAt && Date.now() - fetchedAt.toMillis() < 60 * 60 * 1_000) continue;
    const result = await fetchApiFootballDay(key, date);
    const usable = result.fixtures.filter((item) => isUsableApiFootballFixture(item, allowed));
    for (let offset = 0; offset < usable.length; offset += 400) {
      const batch = db.batch();
      for (const item of usable.slice(offset, offset + 400)) {
        const body = normalizeApiFootballFixture(item);
        batch.set(db.collection("fixtures").doc(`api-football:${item.fixture.id}`), {
          ...body,
          kickoffAt: Timestamp.fromDate(body.kickoffAt),
          syncedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      await batch.commit();
    }
    await marker.set({ date, count: usable.length, scanned: result.fixtures.length, remainingToday: result.remainingToday, fetchedAt: FieldValue.serverTimestamp() });
    console.info("api_football_day_synced", { date, kept: usable.length, scanned: result.fixtures.length, remainingToday: result.remainingToday });
  }
}

async function fixturesInWindow(dateFrom: string, dateTo: string): Promise<Array<Record<string, unknown>>> {
  const snapshot = await getFirestore().collection("fixtures")
    .where("kickoffAt", ">=", Timestamp.fromDate(new Date(`${dateFrom}T00:00:00Z`)))
    .where("kickoffAt", "<", Timestamp.fromDate(new Date(`${dateTo}T00:00:00Z`)))
    .orderBy("kickoffAt")
    .limit(500)
    .get();
  return snapshot.docs.map((document) => publicFixture(document.id, document.data()));
}

function publicFixture(key: string, data: Record<string, unknown>): Record<string, unknown> {
  const kickoff = data.kickoffAt instanceof Timestamp ? data.kickoffAt.toDate() : new Date(String(data.kickoffAt));
  return {
    key,
    version: Number(data.fixtureVersion ?? 1),
    competitionId: String(data.competitionId ?? ""),
    competitionName: String(data.competitionName ?? data.competitionId ?? ""),
    competitionAreaName: typeof data.competitionAreaName === "string" ? data.competitionAreaName : null,
    analysisAvailable: data.analysisAvailable !== false,
    homeTeam: data.homeTeam ?? null,
    awayTeam: data.awayTeam ?? null,
    kickoffAt: kickoff.toISOString(),
    status: String(data.status ?? "scheduled"),
    latestSnapshotId: typeof data.latestSnapshotId === "string" ? data.latestSnapshotId : null,
  };
}
