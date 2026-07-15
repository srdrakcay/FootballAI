import { readFileSync } from "node:fs";
import Ajv2020Module, { type ErrorObject, type ValidateFunction } from "ajv/dist/2020.js";
import addFormatsModule from "ajv-formats";

const Ajv2020 = Ajv2020Module as unknown as new (options: object) => { compile(schema: object): ValidateFunction };
const addFormats = addFormatsModule as unknown as (ajv: object) => void;

type Availability = "available" | "unavailable" | "stale";

export interface ValidationSnapshot {
  snapshotId: string;
  snapshotVersion: number;
  fixture: { fixtureKey: string; fixtureVersion: number; kickoffAt: string };
  sections: Readonly<Record<string, { status: Availability }>>;
}

export interface ExpectedAnalysisIdentity {
  schemaVersion: string;
  fixtureKey: string;
  fixtureVersion: number;
  snapshotId: string;
  snapshotVersion: number;
  promptVersion: string;
  modelVersion: string;
}

interface AnalysisResultShape {
  schemaVersion: string; fixtureKey: string; fixtureVersion: number;
  snapshotId: string; snapshotVersion: number; promptVersion: string; modelVersion: string;
  generatedAt: string; validUntil: string; language: "tr" | "en" | "es" | "fr";
  markets: {
    matchResult: { homePct: number; drawPct: number; awayPct: number };
    goals25: { overPct: number; underPct: number };
    bothTeamsScore: { yesPct: number; noPct: number };
    likelyScores: Array<{ home: number; away: number; pct: number }>;
    likelyScoresTotalPct: number; otherScoresPct: number;
  };
  rationale: Array<{ text: string; evidenceRefs: string[] }>;
}

export type ValidationIssueCode =
  | "SCHEMA_INVALID" | "IDENTITY_MISMATCH" | "PROBABILITY_TOTAL_INVALID"
  | "SCORELINE_DUPLICATE" | "EVIDENCE_UNAVAILABLE" | "TEMPORAL_INVALID"
  | "PROHIBITED_CLAIM";

export interface ValidationIssue { code: ValidationIssueCode; path: string; detail?: string }
export type ValidationResult = { ok: true; value: AnalysisResultShape } | { ok: false; issues: ValidationIssue[] };

const prohibitedPatterns: Readonly<Record<AnalysisResultShape["language"], readonly RegExp[]>> = {
  en: [/\bguaranteed?\b/i, /\bcertain (result|win)\b/i, /\bbet (on|now)\b/i, /\bsure win\b/i],
  tr: [/\bgaranti\b/i, /\bkesin (sonuç|kazan)/i, /\bbahis (yap|oyna)/i, /\bkesinlikle kazan/i],
  es: [/\bgarantizad[oa]\b/i, /\bresultado seguro\b/i, /\bapuesta (por|ahora)\b/i, /\bvictoria segura\b/i],
  fr: [/\bgaranti[e]?\b/i, /\brésultat certain\b/i, /\bpariez (sur|maintenant)\b/i, /\bvictoire certaine\b/i],
};

export class AnalysisResultValidator {
  private readonly schemaValidator: ValidateFunction;

  constructor(schema: object = loadSchema()) {
    const ajv = new Ajv2020({ allErrors: true, strict: true });
    addFormats(ajv);
    this.schemaValidator = ajv.compile(schema);
  }

  validate(candidate: unknown, snapshot: ValidationSnapshot, expected: ExpectedAnalysisIdentity): ValidationResult {
    if (!this.schemaValidator(candidate)) {
      return { ok: false, issues: schemaIssues(this.schemaValidator.errors) };
    }
    const value = candidate as AnalysisResultShape;
    const issues: ValidationIssue[] = [];
    validateIdentity(value, expected, issues);
    validateProbabilities(value, issues);
    validateEvidence(value, snapshot, issues);
    validateTemporal(value, snapshot, issues);
    validateLanguagePolicy(value, issues);
    return issues.length === 0 ? { ok: true, value } : { ok: false, issues };
  }
}

function loadSchema(): object {
  const url = new URL("../../../generated-schemas/analysis-result.schema.json", import.meta.url);
  return JSON.parse(readFileSync(url, "utf8")) as object;
}

function schemaIssues(errors: ErrorObject[] | null | undefined): ValidationIssue[] {
  return (errors ?? []).map((error) => ({ code: "SCHEMA_INVALID", path: error.instancePath || "/", detail: error.keyword }));
}

function validateIdentity(value: AnalysisResultShape, expected: ExpectedAnalysisIdentity, issues: ValidationIssue[]): void {
  for (const key of ["schemaVersion", "fixtureKey", "fixtureVersion", "snapshotId", "snapshotVersion", "promptVersion", "modelVersion"] as const) {
    if (value[key] !== expected[key]) issues.push({ code: "IDENTITY_MISMATCH", path: `/${key}` });
  }
}

function validateProbabilities(value: AnalysisResultShape, issues: ValidationIssue[]): void {
  const markets = value.markets;
  const totals = [
    markets.matchResult.homePct + markets.matchResult.drawPct + markets.matchResult.awayPct,
    markets.goals25.overPct + markets.goals25.underPct,
    markets.bothTeamsScore.yesPct + markets.bothTeamsScore.noPct,
  ];
  if (totals.some((total) => total !== 100)) issues.push({ code: "PROBABILITY_TOTAL_INVALID", path: "/markets" });
  const scoreTotal = markets.likelyScores.reduce((sum, score) => sum + score.pct, 0);
  if (scoreTotal !== markets.likelyScoresTotalPct || scoreTotal + markets.otherScoresPct !== 100) {
    issues.push({ code: "PROBABILITY_TOTAL_INVALID", path: "/markets/likelyScores" });
  }
  const identities = markets.likelyScores.map((score) => `${score.home}:${score.away}`);
  if (new Set(identities).size !== identities.length) issues.push({ code: "SCORELINE_DUPLICATE", path: "/markets/likelyScores" });
}

function validateEvidence(value: AnalysisResultShape, snapshot: ValidationSnapshot, issues: ValidationIssue[]): void {
  value.rationale.forEach((rationale, rationaleIndex) => rationale.evidenceRefs.forEach((reference) => {
    const sectionName = reference.startsWith("sections.") ? reference.slice("sections.".length) : "";
    if (snapshot.sections[sectionName]?.status !== "available") {
      issues.push({ code: "EVIDENCE_UNAVAILABLE", path: `/rationale/${rationaleIndex}/evidenceRefs`, detail: reference });
    }
  }));
}

function validateTemporal(value: AnalysisResultShape, snapshot: ValidationSnapshot, issues: ValidationIssue[]): void {
  const generatedAt = Date.parse(value.generatedAt);
  const validUntil = Date.parse(value.validUntil);
  const kickoffAt = Date.parse(snapshot.fixture.kickoffAt);
  if (!Number.isFinite(generatedAt) || !Number.isFinite(validUntil) || !Number.isFinite(kickoffAt) || validUntil <= generatedAt || validUntil > kickoffAt) {
    issues.push({ code: "TEMPORAL_INVALID", path: "/validUntil" });
  }
}

function validateLanguagePolicy(value: AnalysisResultShape, issues: ValidationIssue[]): void {
  value.rationale.forEach((rationale, index) => {
    if (prohibitedPatterns[value.language].some((pattern) => pattern.test(rationale.text))) {
      issues.push({ code: "PROHIBITED_CLAIM", path: `/rationale/${index}/text` });
    }
  });
}
