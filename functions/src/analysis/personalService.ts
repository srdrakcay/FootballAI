import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { personalFingerprint, storedAIProfile, type AIProfile } from "../profile/aiProfile.js";
import type { SupportedLocale } from "../shared/locales.js";
import {
  buildPersonalPrompt,
  fallbackPersonalLayer,
  personalLayerSchema,
  validatePersonalLayer,
  type BaseAnalysisView,
  type FixtureView,
  type PersonalLayer,
  type PersonalLayerInput,
} from "./personalLayer.js";

export interface StructuredModel {
  generateStructured(request: {
    systemInstruction: string;
    userText: string;
    responseSchema: Record<string, unknown>;
    timeoutMs: number;
    correlationId: string;
    maxOutputTokens?: number;
    temperature?: number;
  }): Promise<{ rawJson: unknown }>;
}

export interface PersonalPayload extends PersonalLayer {
  locale: SupportedLocale;
  source: "model" | "fallback";
  favoriteSide: "home" | "away" | null;
}

/** Model rewrites per user and fixture; beyond this the deterministic layer is used (cost ceiling). */
const maximumModelGenerations = 6;
const personalTimeoutMs = 12_000;

export async function loadAIProfile(uid: string): Promise<AIProfile> {
  const document = await getFirestore().collection("users").doc(uid).collection("private").doc("aiProfile").get();
  return storedAIProfile(document.data());
}

/**
 * Returns the reader's personal layer for an analysis, generating it when missing or when the
 * profile, language or analysis changed since it was written. Never throws because of the model:
 * a failed or invalid generation degrades to the deterministic layer.
 */
export async function ensurePersonalLayer(options: {
  uid: string;
  fixtureKey: string;
  fixtureHash: string;
  locale: SupportedLocale;
  analysis: Record<string, unknown>;
  analysisId: string;
  fixture: Record<string, unknown>;
  correlationId: string;
  model: () => Promise<StructuredModel | null>;
}): Promise<PersonalPayload> {
  const db = getFirestore();
  const reference = db.collection("users").doc(options.uid).collection("personal").doc(options.fixtureHash);
  const [profile, existing] = await Promise.all([loadAIProfile(options.uid), reference.get()]);
  const fingerprint = personalFingerprint(profile, options.locale, options.analysisId);
  const fixture = fixtureView(options.fixture);
  const side = favoriteSideOf(profile, fixture);
  const stored = existing.data();
  if (stored?.fingerprint === fingerprint && isPersonalLayer(stored.layer)) {
    return { ...stored.layer, locale: options.locale, source: stored.source === "model" ? "model" : "fallback", favoriteSide: side };
  }

  const base = baseAnalysisView(options.analysisId, options.analysis);
  const snapshot = await db.collection("fixtures").doc(options.fixtureKey).collection("snapshots").doc("analysis-current-v1").get();
  const sections = (snapshot.data()?.sections ?? {}) as Record<string, { status?: string; data?: unknown }>;
  const availableSections = new Set(Object.entries(sections).filter(([, section]) => section?.status === "available").map(([key]) => key));
  const input: PersonalLayerInput = {
    base,
    fixture,
    profile,
    locale: options.locale,
    availableSections,
    evidence: compactEvidence(sections),
  };

  const generations = Math.max(0, Number(stored?.modelGenerations ?? 0));
  let layer: PersonalLayer | null = null;
  let source: "model" | "fallback" = "fallback";
  if (generations < maximumModelGenerations) {
    const model = await options.model().catch(() => null);
    if (model) {
      try {
        const prompt = buildPersonalPrompt(input);
        const generated = await model.generateStructured({
          ...prompt,
          responseSchema: personalLayerSchema,
          timeoutMs: personalTimeoutMs,
          correlationId: options.correlationId,
          maxOutputTokens: profile.style === "deep" ? 1_400 : 900,
          temperature: 0.35,
        });
        const validation = validatePersonalLayer(generated.rawJson, input);
        if (validation.ok) {
          layer = validation.value;
          source = "model";
        } else {
          console.warn("personal_layer_rejected", { correlationId: options.correlationId, issues: validation.issues });
        }
      } catch (error) {
        console.warn("personal_layer_failed", { correlationId: options.correlationId, error: error instanceof Error ? error.message : "unknown" });
      }
    }
  }
  const resolved = layer ?? fallbackPersonalLayer(input);

  await reference.set({
    schemaVersion: 1,
    fixtureKey: options.fixtureKey,
    analysisId: options.analysisId,
    fingerprint,
    locale: options.locale,
    source,
    layer: resolved,
    modelGenerations: generations + (source === "model" ? 1 : 0),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ...resolved, locale: options.locale, source, favoriteSide: side };
}

/** Shape sent to the app: numbers and evidence codes only. Text lives in the personal layer. */
export function publicAnalysis(analysisId: string, analysis: Record<string, unknown>): Record<string, unknown> {
  const base = baseAnalysisView(analysisId, analysis);
  return {
    analysisId,
    fixtureKey: String(analysis.fixtureKey ?? ""),
    generatedAt: isoDate(analysis.generatedAt),
    validUntil: isoDate(analysis.validUntil),
    markets: base.markets,
    confidence: base.confidence,
    rationale: base.rationale.map(({ code, evidenceRefs }) => ({ code, evidenceRefs })),
    dataAvailability: (analysis.dataAvailability ?? {}) as Record<string, string>,
    limitations: base.limitations,
  };
}

export function baseAnalysisView(analysisId: string, analysis: Record<string, unknown>): BaseAnalysisView {
  const markets = ((analysis.canonicalMarkets ?? analysis.markets) ?? {}) as Record<string, Record<string, unknown> | unknown[]>;
  const match = (markets.matchResult ?? {}) as Record<string, unknown>;
  const goals = (markets.goals25 ?? {}) as Record<string, unknown>;
  const btts = (markets.bothTeamsScore ?? {}) as Record<string, unknown>;
  const scores = Array.isArray(markets.likelyScores) ? markets.likelyScores as Array<Record<string, unknown>> : [];
  const confidence = (analysis.confidence ?? {}) as Record<string, unknown>;
  const level = confidence.level === "low" || confidence.level === "high" ? confidence.level : "medium";
  return {
    analysisId,
    markets: {
      matchResult: { homePct: int(match.homePct), drawPct: int(match.drawPct), awayPct: int(match.awayPct) },
      goals25: { overPct: int(goals.overPct), underPct: int(goals.underPct) },
      bothTeamsScore: { yesPct: int(btts.yesPct), noPct: int(btts.noPct) },
      likelyScores: scores.map((score) => ({ home: int(score.home), away: int(score.away), pct: int(score.pct) })),
      otherScoresPct: int((markets as Record<string, unknown>).otherScoresPct),
    },
    confidence: { level, scorePct: int(confidence.scorePct) },
    rationale: (Array.isArray(analysis.rationale) ? analysis.rationale : [])
      .filter((item): item is Record<string, unknown> => typeof item === "object" && item !== null)
      .map((item) => ({
        code: String(item.code ?? ""),
        text: String(item.text ?? ""),
        evidenceRefs: Array.isArray(item.evidenceRefs) ? item.evidenceRefs.map(String) : [],
      })),
    limitations: Array.isArray(analysis.limitations) ? analysis.limitations.map(String) : [],
  };
}

function fixtureView(fixture: Record<string, unknown>): FixtureView {
  const home = (fixture.homeTeam ?? {}) as Record<string, unknown>;
  const away = (fixture.awayTeam ?? {}) as Record<string, unknown>;
  return {
    homeTeamId: String(home.id ?? ""),
    awayTeamId: String(away.id ?? ""),
    homeTeamName: String(home.name ?? "Home"),
    awayTeamName: String(away.name ?? "Away"),
    competitionName: String(fixture.competitionName ?? fixture.competitionId ?? ""),
    kickoffAt: isoDate(fixture.kickoffAt),
  };
}

function favoriteSideOf(profile: AIProfile, fixture: FixtureView): "home" | "away" | null {
  const id = profile.favoriteTeam?.id;
  if (!id) return null;
  return id === fixture.homeTeamId ? "home" : id === fixture.awayTeamId ? "away" : null;
}

/** Keeps the prompt small: summaries, not raw match lists. */
function compactEvidence(sections: Record<string, { status?: string; data?: unknown }>): Record<string, unknown> {
  const evidence: Record<string, unknown> = {};
  const form = sections.recentForm;
  if (form?.status === "available" && isRecord(form.data)) {
    const strip = (value: unknown) => {
      if (!isRecord(value)) return null;
      const { matches: _matches, ...summary } = value;
      return summary;
    };
    evidence.recentForm = { home: strip(form.data.home), away: strip(form.data.away) };
  }
  if (sections.standings?.status === "available") evidence.standings = sections.standings.data;
  if (sections.headToHead?.status === "available" && Array.isArray(sections.headToHead.data)) {
    evidence.headToHead = sections.headToHead.data.slice(-5);
  }
  return evidence;
}

function isPersonalLayer(value: unknown): value is PersonalLayer {
  return isRecord(value) && typeof value.headline === "string" && typeof value.summary === "string" && Array.isArray(value.keyFactors);
}

function isoDate(value: unknown): string {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  const parsed = new Date(String(value));
  return Number.isFinite(parsed.getTime()) ? parsed.toISOString() : new Date(0).toISOString();
}

function int(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.round(parsed) : 0;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
