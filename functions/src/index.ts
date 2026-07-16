import { createHash, timingSafeEqual } from "node:crypto";
import { readFileSync } from "node:fs";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import { authorize, parsePayload } from "./security/requestGuard.js";
import { FootballDataClient } from "./fixtures/footballDataClient.js";
import { footballDataApiToken, geminiApiKey, requiredSecret, revenueCatWebhookAuthorization, rotatingSecret } from "./security/secrets.js";
import { analysisCreditCost, analysisRuntimeConfiguration } from "./config/runtimeConfig.js";
import { applyCreditAdjustment, parseRevenueCatCreditEvent } from "./revenuecat/creditEvent.js";
import { modelAliases } from "./config/providerRegistry.js";
import { AllowlistedModelAliasResolver } from "./analysis/modelGateway.js";
import { GeminiGateway, GeminiProviderError } from "./analysis/geminiGateway.js";
import { buildAnalysisSnapshot, fixtureInsights, type AnalysisSnapshot } from "./analysis/snapshotBuilder.js";
import { AnalysisResultValidator } from "./analysis/validator.js";

initializeApp();
setGlobalOptions({ region: "europe-west1", maxInstances: 10 });

const supportedLocales = new Set(["tr", "en", "es", "fr"]);
const fixtureDatePattern = /^\d{4}-\d{2}-\d{2}$/;

interface FootballDataMatch {
  id: number;
  utcDate: string;
  status: string;
  lastUpdated?: string;
  competition: { id: number; code?: string | null; name: string };
  homeTeam: { id?: number | null; name?: string | null; shortName?: string | null };
  awayTeam: { id?: number | null; name?: string | null; shortName?: string | null };
}

interface FootballDataMatchList { matches?: FootballDataMatch[] }

export const bootstrapUser = onCall({ enforceAppCheck: true, timeoutSeconds: 10, invoker: "public" }, async (request) => {
  const context = authorize(request);
  const locale = typeof request.data?.locale === "string" && supportedLocales.has(request.data.locale) ? request.data.locale : "en";
  const db = getFirestore();
  const userReference = db.collection("users").doc(context.uid);
  const walletReference = userReference.collection("private").doc("wallet");
  const quotaReference = userReference.collection("private").doc("quota");

  const balance = await db.runTransaction(async (transaction) => {
    const [user, wallet, quota] = await Promise.all([
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

    if (!wallet.exists) {
      const migratedBalance = quota.exists ? Math.max(0, Number(quota.data()?.remaining ?? 0)) : 1;
      transaction.create(walletReference, {
        schemaVersion: 1,
        currency: "credits",
        balance: migratedBalance,
        lifetimeGranted: migratedBalance,
        lifetimePurchased: 0,
        lifetimeSpent: 0,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return migratedBalance;
    }
    return Math.max(0, Number(wallet.data()?.balance ?? 0));
  });

  return { uid: context.uid, balance, analysisCreditCost: await analysisCreditCost() };
});

export const syncFixtures = onCall({
  enforceAppCheck: true,
  timeoutSeconds: 20,
  invoker: "public",
  secrets: [footballDataApiToken],
}, async (request) => {
  authorize(request);
  const { dateFrom, dateTo } = parseFixtureWindow(request.data);
  const db = getFirestore();
  const windowReference = db.collection("fixtureSyncWindows").doc(`${dateFrom}_${dateTo}`);
  const windowSnapshot = await windowReference.get();
  const fetchedAt = windowSnapshot.data()?.fetchedAt as Timestamp | undefined;
  if (fetchedAt && Date.now() - fetchedAt.toMillis() < 15 * 60 * 1_000) {
    return { count: Number(windowSnapshot.data()?.count ?? 0), cached: true };
  }

  const client = new FootballDataClient({ token: await rotatingSecret("FOOTBALL_DATA_API_TOKEN") });
  const response = await client.getMatches<FootballDataMatchList>({ dateFrom, dateTo });
  const matches = (response.data.matches ?? []).filter(validFootballDataMatch);

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
    providerRemainingThisMinute: response.rateLimit.remainingThisMinute,
  });
  return { count: matches.length, cached: false };
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

  const footballClient = new FootballDataClient({ token: await rotatingSecret("FOOTBALL_DATA_API_TOKEN") });
  const snapshot = await cachedOrFreshAnalysisSnapshot(fixtureKey, fixtureSnapshot.data() ?? {}, footballClient);
  return fixtureInsights(snapshot);
});

export const requestAnalysis = onCall({
  enforceAppCheck: true,
  timeoutSeconds: 120,
  memory: "512MiB",
  invoker: "public",
  secrets: [geminiApiKey, footballDataApiToken],
}, async (request) => {
  const context = authorize(request);
  const payload = parsePayload(request.data);
  const reused = await reuseReadyAnalysis(context.uid, payload.fixtureKey);
  if (reused) return reused;

  const runtime = await analysisRuntimeConfiguration();
  if (!runtime.featureAnalysisGenerationEnabled) throw new HttpsError("failed-precondition", "CONFIG_UNAVAILABLE");
  const resolvedModel = new AllowlistedModelAliasResolver(modelAliases).resolve(runtime.modelAlias);
  if (resolvedModel.provider !== "google") throw new HttpsError("failed-precondition", "CONFIG_UNAVAILABLE");

  const db = getFirestore();
  const fixtureReference = db.collection("fixtures").doc(payload.fixtureKey);
  const fixtureSnapshot = await fixtureReference.get();
  if (!fixtureSnapshot.exists) throw new HttpsError("not-found", "FIXTURE_NOT_FOUND");
  const fixture = fixtureSnapshot.data() ?? {};
  const fixtureHash = createHash("sha256").update(payload.fixtureKey).digest("hex");
  const requestId = `req_${createHash("sha256").update(`${context.uid}\u001f${payload.clientRequestId}`).digest("hex").slice(0, 40)}`;
  const reservationId = `res_${createHash("sha256").update(`${context.uid}\u001f${fixtureHash}`).digest("hex")}`;
  const creditCost = await analysisCreditCost();
  const reservation = await reserveAnalysisCredits(context.uid, payload.fixtureKey, fixtureHash, requestId, reservationId, creditCost);
  if (reservation.historyAnalysisId) {
    return { requestId: `history_${fixtureHash.slice(0, 24)}`, analysisId: reservation.historyAnalysisId, state: "ready" };
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

  try {
    const footballClient = new FootballDataClient({ token: await rotatingSecret("FOOTBALL_DATA_API_TOKEN") });
    const snapshot = await cachedOrFreshAnalysisSnapshot(payload.fixtureKey, fixture, footballClient);
    const kickoffAt = new Date(snapshot.fixture.kickoffAt);
    if (kickoffAt.getTime() <= Date.now() + 5 * 60_000) throw new HttpsError("failed-precondition", "FIXTURE_INELIGIBLE");
    const availableSections = Object.values(snapshot.sections).filter((section) => section.status === "available").length;
    if (availableSections < 1) throw new HttpsError("failed-precondition", "DATA_INSUFFICIENT");

    const generatedAt = new Date();
    const validUntil = new Date(Math.min(kickoffAt.getTime() - 60_000, generatedAt.getTime() + analysisTTLSeconds(kickoffAt, generatedAt) * 1_000));
    const analysisId = `ana_${createHash("sha256").update(`${snapshot.contentHash}\u001f${runtime.modelAlias}\u001f${runtime.promptVersion}`).digest("hex")}`;
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
      language: payload.locale,
    };

    await requestReference.set({ state: "validating", updatedAt: FieldValue.serverTimestamp() }, { merge: true });
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
    const validation = new AnalysisResultValidator().validate(generated.rawJson, snapshot, {
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
      throw new HttpsError("internal", "ANALYSIS_VALIDATION_FAILED");
    }

    const analysis = validation.value as unknown as Record<string, unknown>;
    await persistReadyAnalysis(payload.fixtureKey, fixtureHash, analysisId, analysis, generated);
    await finalizeAnalysisCredits(context.uid, fixtureHash, fixture, analysisId, analysis, reservationId, creditCost);
    await requestReference.set({
      state: "ready",
      analysisId,
      providerRequestId: generated.providerRequestId,
      inputTokens: generated.inputTokens ?? null,
      outputTokens: generated.outputTokens ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return { requestId, analysisId, state: "ready" };
  } catch (error) {
    await releaseAnalysisReservation(context.uid, reservationId, creditCost);
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
});

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
  const processed = await db.runTransaction(async (transaction) => {
    const [existingEvent, wallet] = await Promise.all([
      transaction.get(eventReference),
      transaction.get(walletReference),
    ]);
    if (existingEvent.exists) return false;

    const current = wallet.data() ?? {};
    const next = applyCreditAdjustment({
      balance: Number(current.balance ?? 0),
      refundDebt: Number(current.refundDebt ?? 0),
      lifetimePurchased: Number(current.lifetimePurchased ?? 0),
      lifetimeRefunded: Number(current.lifetimeRefunded ?? 0),
    }, event.creditDelta);

    transaction.set(walletReference, {
      schemaVersion: 1,
      currency: "credits",
      ...next,
      lifetimeGranted: Math.max(0, Number(current.lifetimeGranted ?? 0)),
      lifetimeSpent: Math.max(0, Number(current.lifetimeSpent ?? 0)),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
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
    const [wallet, history, existingReservation] = await Promise.all([
      transaction.get(walletReference),
      transaction.get(historyReference),
      transaction.get(reservationReference),
    ]);
    if (history.exists) {
      const analysisId = history.data()?.analysisId;
      return typeof analysisId === "string" ? { historyAnalysisId: analysisId } : {};
    }
    if (!wallet.exists) throw new HttpsError("failed-precondition", "WALLET_UNAVAILABLE");

    const balance = Math.max(0, Number(wallet.data()?.balance ?? 0));
    let reservedCredits = Math.max(0, Number(wallet.data()?.reservedCredits ?? 0));
    const prior = existingReservation.data();
    if (existingReservation.exists && prior?.state === "reserved") {
      const expiresAt = prior.expiresAt as Timestamp | undefined;
      if (expiresAt && expiresAt.toMillis() > Date.now()) {
        throw new HttpsError("aborted", "ANALYSIS_ALREADY_IN_PROGRESS");
      }
      reservedCredits = Math.max(0, reservedCredits - Math.max(0, Number(prior.creditCost ?? 0)));
    }

    const available = Math.max(0, balance - reservedCredits);
    if (available < creditCost) {
      throw new HttpsError("resource-exhausted", "INSUFFICIENT_CREDITS", {
        reason: "INSUFFICIENT_CREDITS",
        balance: available,
        requiredCredits: creditCost,
      });
    }

    transaction.update(walletReference, {
      reservedCredits: reservedCredits + creditCost,
      updatedAt: FieldValue.serverTimestamp(),
    });
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

async function releaseAnalysisReservation(uid: string, reservationId: string, fallbackCreditCost: number): Promise<void> {
  const db = getFirestore();
  const reservationReference = db.collection("quotaReservations").doc(reservationId);
  const walletReference = db.collection("users").doc(uid).collection("private").doc("wallet");
  await db.runTransaction(async (transaction) => {
    const [reservation, wallet] = await Promise.all([
      transaction.get(reservationReference),
      transaction.get(walletReference),
    ]);
    if (!reservation.exists || reservation.data()?.state !== "reserved") return;
    const creditCost = Math.max(0, Number(reservation.data()?.creditCost ?? fallbackCreditCost));
    const reservedCredits = Math.max(0, Number(wallet.data()?.reservedCredits ?? 0));
    if (wallet.exists) {
      transaction.update(walletReference, {
        reservedCredits: Math.max(0, reservedCredits - creditCost),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    transaction.set(reservationReference, {
      state: "released",
      releasedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
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
  await db.runTransaction(async (transaction) => {
    const [wallet, history, reservation] = await Promise.all([
      transaction.get(walletReference),
      transaction.get(historyReference),
      transaction.get(reservationReference),
    ]);
    if (history.exists) {
      if (reservation.exists && reservation.data()?.state === "reserved") {
        const reservedCredits = Math.max(0, Number(wallet.data()?.reservedCredits ?? 0));
        transaction.update(walletReference, {
          reservedCredits: Math.max(0, reservedCredits - creditCost),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.set(reservationReference, { state: "released", releasedAt: FieldValue.serverTimestamp() }, { merge: true });
      }
      return;
    }
    if (!wallet.exists || !reservation.exists || reservation.data()?.state !== "reserved") {
      throw new HttpsError("failed-precondition", "RESERVATION_UNAVAILABLE");
    }
    const balance = Math.max(0, Number(wallet.data()?.balance ?? 0));
    if (balance < creditCost) throw new HttpsError("resource-exhausted", "INSUFFICIENT_CREDITS");
    const reservedCredits = Math.max(0, Number(wallet.data()?.reservedCredits ?? 0));
    const lifetimeSpent = Math.max(0, Number(wallet.data()?.lifetimeSpent ?? 0));
    transaction.update(walletReference, {
      balance: balance - creditCost,
      reservedCredits: Math.max(0, reservedCredits - creditCost),
      lifetimeSpent: lifetimeSpent + creditCost,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(historyReference, analysisHistoryData(fixtureHash, fixture, analysisId, analysis, creditCost));
    transaction.set(reservationReference, {
      state: "committed",
      committedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
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
  return {
    schemaVersion: 1,
    fixtureKey: fixture.fixtureKey ?? analysis.fixtureKey ?? fixtureHash,
    analysisId,
    competitionName: fixture.competitionName ?? fixture.competitionId ?? "Football",
    homeTeamName: (fixture.homeTeam as Record<string, unknown> | undefined)?.name ?? "Home",
    awayTeamName: (fixture.awayTeam as Record<string, unknown> | undefined)?.name ?? "Away",
    kickoffAt: fixture.kickoffAt,
    viewedAt: FieldValue.serverTimestamp(),
    generatedAt: timestampValue(analysis.generatedAt),
    validUntil: timestampValue(analysis.validUntil),
    homeWinProbability: matchResult?.homePct ?? null,
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
  await db.runTransaction(async (transaction) => {
    const [history, wallet] = await Promise.all([transaction.get(historyReference), transaction.get(walletReference)]);
    if (history.exists) return;
    if (!wallet.exists) throw new HttpsError("failed-precondition", "WALLET_UNAVAILABLE");
    const balance = Math.max(0, Number(wallet.data()?.balance ?? 0));
    const reservedCredits = Math.max(0, Number(wallet.data()?.reservedCredits ?? 0));
    const available = Math.max(0, balance - reservedCredits);
    if (available < creditCost) {
      throw new HttpsError("resource-exhausted", "INSUFFICIENT_CREDITS", {
        reason: "INSUFFICIENT_CREDITS",
        balance: available,
        requiredCredits: creditCost,
      });
    }
    const lifetimeSpent = Math.max(0, Number(wallet.data()?.lifetimeSpent ?? 0));
    const canonicalMarkets = analysis.canonicalMarkets as Record<string, unknown> | undefined;
    const matchResult = canonicalMarkets?.matchResult as Record<string, unknown> | undefined;
    transaction.update(walletReference, {
      balance: balance - creditCost,
      lifetimeSpent: lifetimeSpent + creditCost,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(historyReference, analysisHistoryData(fixtureHash, { ...fixture, fixtureKey }, analysisId, analysis, creditCost));
  });
}
