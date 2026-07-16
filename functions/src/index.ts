import { createHash, timingSafeEqual } from "node:crypto";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import { authorize, parsePayload } from "./security/requestGuard.js";
import { FootballDataClient } from "./fixtures/footballDataClient.js";
import { footballDataApiToken, requiredSecret, revenueCatWebhookAuthorization, rotatingSecret } from "./security/secrets.js";
import { analysisCreditCost } from "./config/runtimeConfig.js";
import { applyCreditAdjustment, parseRevenueCatCreditEvent } from "./revenuecat/creditEvent.js";

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

export const requestAnalysis = onCall({ enforceAppCheck: true, timeoutSeconds: 15, invoker: "public" }, async (request) => {
  const context = authorize(request);
  const payload = parsePayload(request.data);
  const reused = await reuseReadyAnalysis(context.uid, payload.fixtureKey);
  if (reused) return reused;
  // Model generation remains fail-closed until an AI provider secret is provisioned.
  console.info("analysis_request_rejected_unconfigured", { correlationId: context.correlationId, uidHashPresent: Boolean(context.uid), fixtureKeyLength: payload.fixtureKey.length });
  throw new HttpsError("failed-precondition", "CONFIG_UNAVAILABLE");
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
    if (balance < creditCost) throw new HttpsError("resource-exhausted", "INSUFFICIENT_CREDITS");
    const lifetimeSpent = Math.max(0, Number(wallet.data()?.lifetimeSpent ?? 0));
    const canonicalMarkets = analysis.canonicalMarkets as Record<string, unknown> | undefined;
    const matchResult = canonicalMarkets?.matchResult as Record<string, unknown> | undefined;
    transaction.update(walletReference, {
      balance: balance - creditCost,
      lifetimeSpent: lifetimeSpent + creditCost,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(historyReference, {
      schemaVersion: 1,
      fixtureKey,
      analysisId,
      competitionName: fixture.competitionName ?? fixture.competitionId ?? "Football",
      homeTeamName: (fixture.homeTeam as Record<string, unknown> | undefined)?.name ?? "Home",
      awayTeamName: (fixture.awayTeam as Record<string, unknown> | undefined)?.name ?? "Away",
      kickoffAt: fixture.kickoffAt,
      viewedAt: FieldValue.serverTimestamp(),
      generatedAt: analysis.generatedAt,
      validUntil: analysis.validUntil,
      homeWinProbability: matchResult?.homePct ?? null,
      creditCost,
    });
  });
}
