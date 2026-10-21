import assert from "node:assert/strict";
import test from "node:test";
import { fallbackPersonalLayer, mentionedPercentages, validatePersonalLayer, type PersonalLayerInput } from "../src/analysis/personalLayer.js";
import { parseAIProfile } from "../src/profile/aiProfile.js";
import type { SupportedLocale } from "../src/shared/locales.js";

function input(locale: SupportedLocale = "tr", profile = parseAIProfile({ favoriteTeam: { id: "1", name: "North City" } })): PersonalLayerInput {
  return {
    locale,
    profile,
    availableSections: new Set(["recentForm", "standings"]),
    evidence: {},
    fixture: { homeTeamId: "1", awayTeamId: "2", homeTeamName: "North City", awayTeamName: "South United", competitionName: "UCL", kickoffAt: "2026-10-21T19:00:00Z" },
    base: {
      analysisId: "ana_1",
      markets: {
        matchResult: { homePct: 46, drawPct: 29, awayPct: 25 },
        goals25: { overPct: 54, underPct: 46 },
        bothTeamsScore: { yesPct: 57, noPct: 43 },
        likelyScores: [{ home: 1, away: 1, pct: 12 }, { home: 2, away: 1, pct: 10 }],
        otherScoresPct: 78,
      },
      confidence: { level: "medium", scorePct: 63 },
      rationale: [{ code: "FORM", text: "Home form is stronger.", evidenceRefs: ["sections.recentForm"] }],
      limitations: ["LINEUPS_UNAVAILABLE"],
    },
  };
}

const valid = {
  headline: "North City hafif favori",
  summary: "Ev sahibi %46 ile önde, beraberlik %29. Gol tarafında 2,5 üst %54.",
  forYou: "Takımının kazanma olasılığı %46.",
  keyFactors: [{ section: "recentForm", text: "Ev sahibinin son maçlardaki formu daha istikrarlı." }],
  watchNote: "İlk 11'ler henüz açıklanmadı.",
};

test("a well-formed personal layer passes", () => {
  const result = validatePersonalLayer(valid, input());
  assert.equal(result.ok, true);
});

test("invented probabilities are rejected", () => {
  const result = validatePersonalLayer({ ...valid, summary: "Ev sahibi %71 ile çok önde, deplasman zor durumda." }, input());
  assert.deepEqual(result.ok ? [] : result.issues, ["UNKNOWN_PROBABILITY"]);
});

test("citing a section without data is rejected", () => {
  const result = validatePersonalLayer({ ...valid, keyFactors: [{ section: "lineups", text: "İlk 11 çok güçlü görünüyor." }] }, input());
  assert.equal(result.ok, false);
});

test("betting and certainty language is rejected per language", () => {
  assert.equal(validatePersonalLayer({ ...valid, headline: "Bu maç banko ev sahibi" }, input()).ok, false);
  const german = { ...valid, headline: "Ein sicherer Sieg für North City", summary: "North City liegt mit 46 % vorne, Unentschieden 29 %." };
  assert.equal(validatePersonalLayer(german, input("de")).ok, false);
});

test("brief style limits the number of factors", () => {
  const profile = parseAIProfile({ style: "brief" });
  const factors = Array.from({ length: 3 }, () => ({ section: "recentForm", text: "Form tablosu ev sahibinden yana." }));
  assert.equal(validatePersonalLayer({ ...valid, keyFactors: factors }, input("tr", profile)).ok, false);
});

test("percentage detection follows each language's notation", () => {
  assert.deepEqual(mentionedPercentages("Ev sahibi %46, yüzde 29 beraberlik", "tr"), [46, 29]);
  assert.deepEqual(mentionedPercentages("Home 46%, over 2.5 goals 54 %", "en"), [46, 54]);
  assert.deepEqual(mentionedPercentages("Über 2,5 Tore liegt bei 54 Prozent", "de"), [54]);
});

test("fallback is valid in every language and speaks to the favorite team", () => {
  for (const locale of ["tr", "en", "de", "es", "fr"] as const) {
    const context = input(locale);
    const layer = fallbackPersonalLayer(context);
    assert.equal(validatePersonalLayer(layer, context).ok, true, locale);
    assert.ok(layer.forYou?.includes("North City"), locale);
    assert.ok(layer.watchNote, locale);
  }
});

test("fallback headline reflects how close the match is", () => {
  const close = input("en");
  close.base.markets.matchResult = { homePct: 36, drawPct: 33, awayPct: 31 };
  assert.match(fallbackPersonalLayer(close).headline, /balanced/);
  const clear = input("en");
  clear.base.markets.matchResult = { homePct: 62, drawPct: 22, awayPct: 16 };
  assert.match(fallbackPersonalLayer(clear).headline, /edge/);
});
