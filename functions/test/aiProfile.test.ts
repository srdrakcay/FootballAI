import assert from "node:assert/strict";
import test from "node:test";
import { AIProfileValidationError, favoriteSide, parseAIProfile, personalFingerprint, storedAIProfile } from "../src/profile/aiProfile.js";
import { resolveLocale } from "../src/shared/locales.js";

test("valid profile is normalized", () => {
  const profile = parseAIProfile({
    favoriteTeam: { id: "65", name: "  North City " },
    competitionIds: ["PL", "CL", "PL"],
    style: "deep",
    focusMarkets: ["scorelines", "matchResult"],
  });
  assert.deepEqual(profile, {
    favoriteTeam: { id: "65", name: "North City" },
    competitionIds: ["CL", "PL"],
    style: "deep",
    focusMarkets: ["matchResult", "scorelines"],
  });
});

test("unknown fields and bad values are rejected", () => {
  assert.throws(() => parseAIProfile({ admin: true }), AIProfileValidationError);
  assert.throws(() => parseAIProfile({ style: "aggressive" }), AIProfileValidationError);
  assert.throws(() => parseAIProfile({ focusMarkets: [] }), AIProfileValidationError);
  assert.throws(() => parseAIProfile({ competitionIds: ["pl; drop"] }), AIProfileValidationError);
  assert.throws(() => parseAIProfile({ favoriteTeam: { id: "../x", name: "A" } }), AIProfileValidationError);
});

test("stored profiles degrade to defaults instead of failing", () => {
  assert.equal(storedAIProfile({ style: "nonsense" }).style, "balanced");
  assert.equal(storedAIProfile(undefined).favoriteTeam, null);
  assert.equal(storedAIProfile({ style: "brief", updatedAt: 5, schemaVersion: 1 }).style, "brief");
});

test("fingerprint changes with style, locale and team but not with league list", () => {
  const base = parseAIProfile({ style: "balanced" });
  const id = personalFingerprint(base, "tr", "ana_1");
  assert.notEqual(id, personalFingerprint({ ...base, style: "brief" }, "tr", "ana_1"));
  assert.notEqual(id, personalFingerprint(base, "de", "ana_1"));
  assert.notEqual(id, personalFingerprint(base, "tr", "ana_2"));
  assert.equal(id, personalFingerprint({ ...base, competitionIds: ["PL"] }, "tr", "ana_1"));
});

test("favorite side is resolved from team ids", () => {
  const profile = parseAIProfile({ favoriteTeam: { id: "7", name: "X" } });
  assert.equal(favoriteSide(profile, "7", "9"), "home");
  assert.equal(favoriteSide(profile, "9", "7"), "away");
  assert.equal(favoriteSide(profile, "1", "2"), null);
});

test("German is a supported locale and regional identifiers resolve", () => {
  assert.equal(resolveLocale("de"), "de");
  assert.equal(resolveLocale("de_AT"), "de");
  assert.equal(resolveLocale("pt-BR"), "en");
});
