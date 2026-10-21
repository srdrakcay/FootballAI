import { favoriteSide, type AIProfile, type AnalysisStyle } from "../profile/aiProfile.js";
import { violatesLanguagePolicy } from "../shared/languagePolicy.js";
import { localeDisplayName, type SupportedLocale } from "../shared/locales.js";

/**
 * The personal layer sits on top of one shared, cached analysis. The shared layer owns every
 * number; the personal layer only explains those numbers in the reader's language, at the depth
 * they chose, from the angle of the team and markets they care about. It may never introduce a
 * probability that the shared layer does not contain.
 */

export const evidenceSections = ["recentForm", "headToHead", "standings", "squadAvailability", "lineups", "weather"] as const;
export type EvidenceSection = (typeof evidenceSections)[number];

export interface BaseAnalysisView {
  analysisId: string;
  markets: {
    matchResult: { homePct: number; drawPct: number; awayPct: number };
    goals25: { overPct: number; underPct: number };
    bothTeamsScore: { yesPct: number; noPct: number };
    likelyScores: Array<{ home: number; away: number; pct: number }>;
    otherScoresPct: number;
  };
  confidence: { level: "low" | "medium" | "high"; scorePct: number };
  rationale: Array<{ code: string; text: string; evidenceRefs: string[] }>;
  limitations: string[];
}

export interface FixtureView {
  homeTeamId: string;
  awayTeamId: string;
  homeTeamName: string;
  awayTeamName: string;
  competitionName: string;
  kickoffAt: string;
}

export interface PersonalLayerInput {
  base: BaseAnalysisView;
  fixture: FixtureView;
  profile: AIProfile;
  locale: SupportedLocale;
  availableSections: ReadonlySet<string>;
  /** Compact, already-public match data the model may cite. */
  evidence: Readonly<Record<string, unknown>>;
}

export interface PersonalKeyFactor { section: EvidenceSection; text: string }

export interface PersonalLayer {
  headline: string;
  summary: string;
  forYou: string | null;
  keyFactors: PersonalKeyFactor[];
  watchNote: string | null;
}

export type PersonalValidationIssue =
  | "SCHEMA_INVALID" | "LENGTH_INVALID" | "EVIDENCE_UNAVAILABLE"
  | "UNKNOWN_PROBABILITY" | "PROHIBITED_CLAIM" | "FACTOR_COUNT_INVALID";

export type PersonalValidationResult =
  | { ok: true; value: PersonalLayer }
  | { ok: false; issues: PersonalValidationIssue[] };

const styleLimits: Readonly<Record<AnalysisStyle, { summary: number; factors: number }>> = {
  brief: { summary: 280, factors: 2 },
  balanced: { summary: 520, factors: 3 },
  deep: { summary: 900, factors: 5 },
};

export const personalLayerSchema: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  required: ["headline", "summary", "forYou", "keyFactors", "watchNote"],
  properties: {
    headline: { type: "string", maxLength: 110 },
    summary: { type: "string", maxLength: 900 },
    forYou: { type: ["string", "null"], maxLength: 420 },
    keyFactors: {
      type: "array",
      minItems: 1,
      maxItems: 5,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["section", "text"],
        properties: {
          section: { enum: [...evidenceSections] },
          text: { type: "string", maxLength: 240 },
        },
      },
    },
    watchNote: { type: ["string", "null"], maxLength: 240 },
  },
};

export function buildPersonalPrompt(input: PersonalLayerInput): { systemInstruction: string; userText: string } {
  const side = favoriteSide(input.profile, input.fixture.homeTeamId, input.fixture.awayTeamId);
  const limits = styleLimits[input.profile.style];
  const language = localeDisplayName[input.locale];
  const systemInstruction = [
    "You write the personal explanation layer of a football match analysis app.",
    `Write every text field in ${language}. Use natural, fluent ${language}; never mix languages.`,
    "All probabilities come from BASE_ANALYSIS. Never invent, round differently, or add any percentage that is not in BASE_ANALYSIS.",
    "Use only facts from BASE_ANALYSIS and EVIDENCE. Never use outside knowledge about these teams, players, or competitions.",
    "Never promise an outcome, never recommend betting, never use certainty words. Speak about tendencies and likelihoods.",
    `Style "${input.profile.style}": summary at most ${limits.summary} characters, exactly 1 to ${limits.factors} keyFactors.`,
    "headline: one short sentence (max 110 characters) that captures the overall picture.",
    "keyFactors: each cites exactly one section that is listed in AVAILABLE_SECTIONS.",
    side
      ? `forYou: the reader supports the ${side} team (${side === "home" ? input.fixture.homeTeamName : input.fixture.awayTeamName}). Speak to them about their team's chances and what to watch, respectfully and without cheerleading.`
      : "forYou: the reader has no team in this match. Address their focus markets instead, or return null if there is nothing useful to add.",
    `The reader cares most about: ${input.profile.focusMarkets.join(", ")}. Emphasize these markets in summary and forYou.`,
    "watchNote: one sentence about the most important missing or uncertain data (from BASE_ANALYSIS.limitations), or null.",
    "Return only JSON matching the response schema.",
  ].join("\n");

  const userText = [
    "FIXTURE_JSON",
    JSON.stringify(input.fixture),
    "BASE_ANALYSIS_JSON",
    JSON.stringify({
      markets: input.base.markets,
      confidence: input.base.confidence,
      rationale: input.base.rationale.map(({ code, text, evidenceRefs }) => ({ code, text, evidenceRefs })),
      limitations: input.base.limitations,
    }),
    "AVAILABLE_SECTIONS_JSON",
    JSON.stringify([...input.availableSections]),
    "EVIDENCE_JSON",
    JSON.stringify(input.evidence),
  ].join("\n");

  return { systemInstruction, userText };
}

export function validatePersonalLayer(raw: unknown, input: PersonalLayerInput): PersonalValidationResult {
  if (!isRecord(raw)) return { ok: false, issues: ["SCHEMA_INVALID"] };
  const headline = cleanText(raw.headline);
  const summary = cleanText(raw.summary);
  const forYou = raw.forYou === null || raw.forYou === undefined ? null : cleanText(raw.forYou);
  const watchNote = raw.watchNote === null || raw.watchNote === undefined ? null : cleanText(raw.watchNote);
  if (headline === null || summary === null || !Array.isArray(raw.keyFactors)) return { ok: false, issues: ["SCHEMA_INVALID"] };
  if (raw.forYou !== null && raw.forYou !== undefined && forYou === null) return { ok: false, issues: ["SCHEMA_INVALID"] };
  if (raw.watchNote !== null && raw.watchNote !== undefined && watchNote === null) return { ok: false, issues: ["SCHEMA_INVALID"] };

  const issues = new Set<PersonalValidationIssue>();
  const limits = styleLimits[input.profile.style];
  if (headline.length < 6 || headline.length > 110) issues.add("LENGTH_INVALID");
  if (summary.length < 20 || summary.length > limits.summary) issues.add("LENGTH_INVALID");
  if (forYou !== null && forYou.length > 420) issues.add("LENGTH_INVALID");
  if (watchNote !== null && watchNote.length > 240) issues.add("LENGTH_INVALID");

  const keyFactors: PersonalKeyFactor[] = [];
  for (const item of raw.keyFactors) {
    if (!isRecord(item)) { issues.add("SCHEMA_INVALID"); continue; }
    const text = cleanText(item.text);
    const section = item.section;
    if (text === null || typeof section !== "string" || !(evidenceSections as readonly string[]).includes(section)) {
      issues.add("SCHEMA_INVALID");
      continue;
    }
    if (!input.availableSections.has(section)) issues.add("EVIDENCE_UNAVAILABLE");
    if (text.length < 8 || text.length > 240) issues.add("LENGTH_INVALID");
    keyFactors.push({ section: section as EvidenceSection, text });
  }
  if (keyFactors.length < 1 || keyFactors.length > limits.factors) issues.add("FACTOR_COUNT_INVALID");

  const texts = [headline, summary, forYou, watchNote, ...keyFactors.map((factor) => factor.text)].filter((value): value is string => value !== null);
  const allowed = allowedPercentages(input.base);
  if (texts.some((text) => mentionedPercentages(text, input.locale).some((value) => !allowed.has(value)))) issues.add("UNKNOWN_PROBABILITY");
  if (texts.some((text) => violatesLanguagePolicy(input.locale, text))) issues.add("PROHIBITED_CLAIM");

  return issues.size === 0
    ? { ok: true, value: { headline, summary, forYou, keyFactors, watchNote } }
    : { ok: false, issues: [...issues] };
}

export function allowedPercentages(base: BaseAnalysisView): Set<number> {
  const { matchResult, goals25, bothTeamsScore, likelyScores, otherScoresPct } = base.markets;
  return new Set([
    matchResult.homePct, matchResult.drawPct, matchResult.awayPct,
    goals25.overPct, goals25.underPct, bothTeamsScore.yesPct, bothTeamsScore.noPct,
    ...likelyScores.map((score) => score.pct), otherScoresPct, base.confidence.scorePct,
  ]);
}

/** Finds percentage mentions the way each language writes them ("%46", "46%", "46 %", "yüzde 46", "46 Prozent"). */
export function mentionedPercentages(text: string, locale: SupportedLocale): number[] {
  const pattern = locale === "tr"
    ? /%\s?(\d{1,3})(?!\d)|yüzde\s(\d{1,3})(?!\d)|(?<![\d.,])(\d{1,3})\s?%/gi
    : /(?<![\d.,])(\d{1,3})\s?(?:%|per ?cent|prozent|por ciento|pour cent)/gi;
  const values: number[] = [];
  for (const match of text.matchAll(pattern)) {
    const value = Number(match[1] ?? match[2] ?? match[3]);
    if (Number.isFinite(value)) values.push(value);
  }
  return values;
}

// MARK: - Deterministic fallback

interface FallbackCopy {
  pct(value: number): string;
  draw: string;
  slightFavorite(team: string): string;
  favorite(team: string): string;
  balanced: string;
  summary(home: string, homePct: string, draw: string, away: string, awayPct: string, over: string, btts: string): string;
  forTeam(team: string, win: string, draw: string): string;
  goalsFocus(over: string, btts: string): string;
  scoreFocus(score: string, pct: string): string;
  factor: Readonly<Record<EvidenceSection, string>>;
  watch: Readonly<Record<"lineups" | "squad" | "generic", string>>;
}

const copy: Readonly<Record<SupportedLocale, FallbackCopy>> = {
  tr: {
    pct: (value) => `%${value}`,
    draw: "beraberlik",
    slightFavorite: (team) => `${team} hafif favori görünüyor`,
    favorite: (team) => `${team} öne çıkan taraf`,
    balanced: "Dengeli bir maç bekleniyor",
    summary: (h, hp, d, a, ap, o, b) => `${h} ${hp}, beraberlik ${d}, ${a} ${ap}. 2,5 üst olasılığı ${o}, karşılıklı gol olasılığı ${b}.`,
    forTeam: (t, w, d) => `${t} için galibiyet olasılığı ${w}, beraberlik ${d}.`,
    goalsFocus: (o, b) => `Gol tarafında 2,5 üst ${o}, karşılıklı gol ${b}.`,
    scoreFocus: (s, p) => `En olası skor ${s} (${p}).`,
    factor: {
      recentForm: "Son maçlardaki form olasılıklara yansıtıldı.",
      headToHead: "İki takımın aralarındaki son maçlar hesaba katıldı.",
      standings: "Puan durumundaki konumlar değerlendirildi.",
      squadAvailability: "Kadro durumu değerlendirildi.",
      lineups: "Açıklanan ilk 11'ler değerlendirildi.",
      weather: "Hava koşulları değerlendirildi.",
    },
    watch: {
      lineups: "İlk 11'ler henüz açıklanmadı; olasılıklar kadroya göre değişebilir.",
      squad: "Sakatlık ve ceza bilgisi bu analizde yer almıyor.",
      generic: "Bazı veriler eksik olduğu için güven seviyesi sınırlı.",
    },
  },
  en: {
    pct: (value) => `${value}%`,
    draw: "draw",
    slightFavorite: (team) => `${team} are slight favorites`,
    favorite: (team) => `${team} have the edge`,
    balanced: "A closely balanced match is expected",
    summary: (h, hp, d, a, ap, o, b) => `${h} ${hp}, draw ${d}, ${a} ${ap}. Over 2.5 goals ${o}, both teams to score ${b}.`,
    forTeam: (t, w, d) => `${t} have a ${w} chance to win and ${d} to draw.`,
    goalsFocus: (o, b) => `On goals: over 2.5 ${o}, both teams to score ${b}.`,
    scoreFocus: (s, p) => `Most likely scoreline: ${s} (${p}).`,
    factor: {
      recentForm: "Recent form is reflected in the probabilities.",
      headToHead: "Recent meetings between the teams were considered.",
      standings: "League positions were taken into account.",
      squadAvailability: "Squad availability was considered.",
      lineups: "Confirmed lineups were considered.",
      weather: "Weather conditions were considered.",
    },
    watch: {
      lineups: "Lineups are not confirmed yet; probabilities may shift with team news.",
      squad: "Injury and suspension data is not included in this analysis.",
      generic: "Some data is missing, so confidence is limited.",
    },
  },
  de: {
    pct: (value) => `${value} %`,
    draw: "Unentschieden",
    slightFavorite: (team) => `${team} ist leichter Favorit`,
    favorite: (team) => `${team} hat die besseren Karten`,
    balanced: "Ein ausgeglichenes Spiel wird erwartet",
    summary: (h, hp, d, a, ap, o, b) => `${h} ${hp}, Unentschieden ${d}, ${a} ${ap}. Über 2,5 Tore ${o}, beide Teams treffen ${b}.`,
    forTeam: (t, w, d) => `${t} gewinnt mit ${w}, Unentschieden ${d}.`,
    goalsFocus: (o, b) => `Bei den Toren: über 2,5 ${o}, beide Teams treffen ${b}.`,
    scoreFocus: (s, p) => `Wahrscheinlichstes Ergebnis: ${s} (${p}).`,
    factor: {
      recentForm: "Die aktuelle Form fließt in die Wahrscheinlichkeiten ein.",
      headToHead: "Die letzten direkten Duelle wurden berücksichtigt.",
      standings: "Die Tabellenplätze wurden berücksichtigt.",
      squadAvailability: "Die Kaderlage wurde berücksichtigt.",
      lineups: "Die Aufstellungen wurden berücksichtigt.",
      weather: "Die Wetterbedingungen wurden berücksichtigt.",
    },
    watch: {
      lineups: "Die Aufstellungen stehen noch nicht fest; die Werte können sich ändern.",
      squad: "Verletzungen und Sperren sind in dieser Analyse nicht enthalten.",
      generic: "Einige Daten fehlen, daher ist die Aussagekraft begrenzt.",
    },
  },
  es: {
    pct: (value) => `${value} %`,
    draw: "empate",
    slightFavorite: (team) => `${team} parte como ligero favorito`,
    favorite: (team) => `${team} tiene ventaja`,
    balanced: "Se espera un partido equilibrado",
    summary: (h, hp, d, a, ap, o, b) => `${h} ${hp}, empate ${d}, ${a} ${ap}. Más de 2,5 goles ${o}, ambos marcan ${b}.`,
    forTeam: (t, w, d) => `${t} tiene un ${w} de ganar y un ${d} de empatar.`,
    goalsFocus: (o, b) => `En goles: más de 2,5 ${o}, ambos marcan ${b}.`,
    scoreFocus: (s, p) => `Resultado más probable: ${s} (${p}).`,
    factor: {
      recentForm: "La forma reciente se refleja en las probabilidades.",
      headToHead: "Se tuvieron en cuenta los últimos enfrentamientos.",
      standings: "Se consideraron las posiciones en la tabla.",
      squadAvailability: "Se consideró la disponibilidad de la plantilla.",
      lineups: "Se consideraron las alineaciones confirmadas.",
      weather: "Se consideraron las condiciones meteorológicas.",
    },
    watch: {
      lineups: "Las alineaciones aún no están confirmadas; las probabilidades pueden cambiar.",
      squad: "Este análisis no incluye lesiones ni sanciones.",
      generic: "Faltan algunos datos, por lo que la confianza es limitada.",
    },
  },
  fr: {
    pct: (value) => `${value} %`,
    draw: "nul",
    slightFavorite: (team) => `${team} part légèrement favori`,
    favorite: (team) => `${team} a l’avantage`,
    balanced: "Un match équilibré est attendu",
    summary: (h, hp, d, a, ap, o, b) => `${h} ${hp}, nul ${d}, ${a} ${ap}. Plus de 2,5 buts ${o}, les deux équipes marquent ${b}.`,
    forTeam: (t, w, d) => `${t} a ${w} de chances de gagner et ${d} de faire match nul.`,
    goalsFocus: (o, b) => `Côté buts : plus de 2,5 ${o}, les deux équipes marquent ${b}.`,
    scoreFocus: (s, p) => `Score le plus probable : ${s} (${p}).`,
    factor: {
      recentForm: "La forme récente est prise en compte dans les probabilités.",
      headToHead: "Les dernières confrontations directes ont été prises en compte.",
      standings: "Les positions au classement ont été prises en compte.",
      squadAvailability: "La disponibilité de l’effectif a été prise en compte.",
      lineups: "Les compositions officielles ont été prises en compte.",
      weather: "Les conditions météo ont été prises en compte.",
    },
    watch: {
      lineups: "Les compositions ne sont pas encore connues ; les probabilités peuvent évoluer.",
      squad: "Les blessures et suspensions ne figurent pas dans cette analyse.",
      generic: "Certaines données manquent, la confiance est donc limitée.",
    },
  },
};

/** Always succeeds. Used when the model is unavailable or its output fails validation. */
export function fallbackPersonalLayer(input: PersonalLayerInput): PersonalLayer {
  const text = copy[input.locale];
  const { matchResult, goals25, bothTeamsScore, likelyScores } = input.base.markets;
  const { homeTeamName: home, awayTeamName: away } = input.fixture;
  const leaderIsHome = matchResult.homePct >= matchResult.awayPct;
  const leaderPct = Math.max(matchResult.homePct, matchResult.awayPct);
  const otherPct = Math.min(matchResult.homePct, matchResult.awayPct);
  const leader = leaderIsHome ? home : away;
  const margin = leaderPct - Math.max(otherPct, matchResult.drawPct);
  const headline = margin >= 20 ? text.favorite(leader) : margin >= 8 ? text.slightFavorite(leader) : text.balanced;

  const summary = text.summary(
    home, text.pct(matchResult.homePct), text.pct(matchResult.drawPct),
    away, text.pct(matchResult.awayPct), text.pct(goals25.overPct), text.pct(bothTeamsScore.yesPct),
  );

  const parts: string[] = [];
  const side = favoriteSide(input.profile, input.fixture.homeTeamId, input.fixture.awayTeamId);
  if (side) {
    parts.push(text.forTeam(side === "home" ? home : away, text.pct(side === "home" ? matchResult.homePct : matchResult.awayPct), text.pct(matchResult.drawPct)));
  }
  if (input.profile.focusMarkets.includes("goals") || input.profile.focusMarkets.includes("bothTeamsScore")) {
    parts.push(text.goalsFocus(text.pct(goals25.overPct), text.pct(bothTeamsScore.yesPct)));
  }
  const topScore = [...likelyScores].sort((first, second) => second.pct - first.pct)[0];
  if (topScore && input.profile.focusMarkets.includes("scorelines")) {
    parts.push(text.scoreFocus(`${topScore.home}-${topScore.away}`, text.pct(topScore.pct)));
  }

  const cited = new Set<EvidenceSection>();
  for (const item of input.base.rationale) {
    for (const reference of item.evidenceRefs) {
      const section = reference.replace(/^sections\./, "");
      if ((evidenceSections as readonly string[]).includes(section) && input.availableSections.has(section)) cited.add(section as EvidenceSection);
    }
  }
  if (cited.size === 0) {
    for (const section of evidenceSections) if (input.availableSections.has(section)) cited.add(section);
  }
  const keyFactors = [...cited].slice(0, styleLimits[input.profile.style].factors).map((section) => ({ section, text: text.factor[section] }));
  if (keyFactors.length === 0) keyFactors.push({ section: "recentForm", text: text.factor.recentForm });

  const limitations = input.base.limitations.join(" ");
  const watchNote = /LINEUP/.test(limitations) || !input.availableSections.has("lineups")
    ? text.watch.lineups
    : /SQUAD|INJUR/.test(limitations) ? text.watch.squad
      : input.base.confidence.level === "low" ? text.watch.generic : null;

  return { headline, summary, forYou: parts.length > 0 ? parts.join(" ") : null, keyFactors, watchNote };
}

function cleanText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  return value.replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "").replace(/\s+/g, " ").trim();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
