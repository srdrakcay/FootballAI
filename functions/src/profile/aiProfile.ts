import { createHash } from "node:crypto";
import type { SupportedLocale } from "../shared/locales.js";

export const analysisStyles = ["brief", "balanced", "deep"] as const;
export type AnalysisStyle = (typeof analysisStyles)[number];

export const focusMarkets = ["matchResult", "goals", "bothTeamsScore", "scorelines"] as const;
export type FocusMarket = (typeof focusMarkets)[number];

export interface AIProfile {
  favoriteTeam: { id: string; name: string } | null;
  competitionIds: string[];
  style: AnalysisStyle;
  focusMarkets: FocusMarket[];
}

export const defaultAIProfile: AIProfile = Object.freeze({
  favoriteTeam: null,
  competitionIds: [],
  style: "balanced",
  focusMarkets: ["matchResult", "goals"],
}) as AIProfile;

const competitionPattern = /^[A-Z0-9]{2,8}$/;
const teamIdPattern = /^[A-Za-z0-9_-]{1,40}$/;
const allowedKeys = new Set(["favoriteTeam", "competitionIds", "style", "focusMarkets"]);

export class AIProfileValidationError extends Error {}

/** Strict parser for client input. Unknown fields or malformed values are rejected, never coerced. */
export function parseAIProfile(input: unknown): AIProfile {
  if (!isRecord(input)) throw new AIProfileValidationError("INVALID_PROFILE");
  if (Object.keys(input).some((key) => !allowedKeys.has(key))) throw new AIProfileValidationError("UNKNOWN_PROFILE_FIELD");

  let favoriteTeam: AIProfile["favoriteTeam"] = null;
  if (input.favoriteTeam !== null && input.favoriteTeam !== undefined) {
    if (!isRecord(input.favoriteTeam)) throw new AIProfileValidationError("INVALID_FAVORITE_TEAM");
    const id = input.favoriteTeam.id;
    const name = input.favoriteTeam.name;
    if (typeof id !== "string" || !teamIdPattern.test(id)) throw new AIProfileValidationError("INVALID_FAVORITE_TEAM");
    if (typeof name !== "string" || name.trim().length === 0 || name.length > 60) throw new AIProfileValidationError("INVALID_FAVORITE_TEAM");
    favoriteTeam = { id, name: sanitizeName(name) };
  }

  const competitionIds = input.competitionIds ?? [];
  if (!Array.isArray(competitionIds) || competitionIds.length > 12
    || competitionIds.some((value) => typeof value !== "string" || !competitionPattern.test(value))) {
    throw new AIProfileValidationError("INVALID_COMPETITIONS");
  }

  const style = input.style ?? "balanced";
  if (typeof style !== "string" || !(analysisStyles as readonly string[]).includes(style)) {
    throw new AIProfileValidationError("INVALID_STYLE");
  }

  const markets = input.focusMarkets ?? defaultAIProfile.focusMarkets;
  if (!Array.isArray(markets) || markets.length === 0 || markets.length > focusMarkets.length
    || markets.some((value) => typeof value !== "string" || !(focusMarkets as readonly string[]).includes(value))) {
    throw new AIProfileValidationError("INVALID_FOCUS_MARKETS");
  }

  return {
    favoriteTeam,
    competitionIds: [...new Set(competitionIds as string[])].sort(),
    style: style as AnalysisStyle,
    focusMarkets: focusMarkets.filter((market) => (markets as string[]).includes(market)),
  };
}

/** Lenient reader for stored documents: falls back to defaults instead of throwing. */
export function storedAIProfile(value: unknown): AIProfile {
  try {
    return parseAIProfile(isRecord(value) ? pick(value) : {});
  } catch {
    return { ...defaultAIProfile, focusMarkets: [...defaultAIProfile.focusMarkets] };
  }
}

/** Identifies the inputs that shape a personal layer; a change means it must be rewritten. */
export function personalFingerprint(profile: AIProfile, locale: SupportedLocale, analysisId: string): string {
  const canonical = JSON.stringify([
    analysisId,
    locale,
    profile.favoriteTeam?.id ?? null,
    profile.style,
    profile.focusMarkets,
  ]);
  return createHash("sha256").update(canonical).digest("hex").slice(0, 32);
}

export function favoriteSide(profile: AIProfile, homeTeamId: string, awayTeamId: string): "home" | "away" | null {
  const id = profile.favoriteTeam?.id;
  if (!id) return null;
  if (id === homeTeamId) return "home";
  if (id === awayTeamId) return "away";
  return null;
}

function sanitizeName(value: string): string {
  return value.replace(/[\u0000-\u001f<>]/g, "").trim();
}

function pick(value: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries([...allowedKeys].filter((key) => key in value).map((key) => [key, value[key]]));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
