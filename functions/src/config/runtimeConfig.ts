import { getRemoteConfig } from "firebase-admin/remote-config";
import { validateRuntimeConfiguration, type RuntimeConfiguration } from "./validator.js";
import { parseLeagueAllowlist } from "../fixtures/apiFootball.js";

const cacheDurationMs = 60_000;
let cachedAnalysisCreditCost: { value: number; expiresAt: number } | undefined;
let cachedWelcomeCredits: { value: number; expiresAt: number } | undefined;
let cachedRuntimeConfiguration: { value: RuntimeConfiguration; expiresAt: number } | undefined;

export async function analysisCreditCost(): Promise<number> {
  const now = Date.now();
  if (cachedAnalysisCreditCost && cachedAnalysisCreditCost.expiresAt > now) return cachedAnalysisCreditCost.value;

  let value = 1;
  try {
    const template = await getRemoteConfig().getTemplate();
    const raw = template.parameters.analysis_credit_cost?.defaultValue;
    const candidate = raw && "value" in raw ? Number(raw.value) : Number.NaN;
    if (Number.isSafeInteger(candidate) && candidate >= 1 && candidate <= 100) value = candidate;
    else console.warn("invalid_analysis_credit_cost_using_default");
  } catch (error) {
    console.error("remote_config_fetch_failed_using_default", { error: error instanceof Error ? error.message : "unknown" });
  }

  cachedAnalysisCreditCost = { value, expiresAt: now + cacheDurationMs };
  return value;
}

/** Credits granted to a brand-new wallet. Remote Config `welcome_credits`; 0 when missing or invalid. */
export async function welcomeCredits(): Promise<number> {
  const now = Date.now();
  if (cachedWelcomeCredits && cachedWelcomeCredits.expiresAt > now) return cachedWelcomeCredits.value;

  let value = 0;
  try {
    const template = await getRemoteConfig().getTemplate();
    const raw = template.parameters.welcome_credits?.defaultValue;
    const candidate = raw && "value" in raw ? Number(raw.value) : Number.NaN;
    if (Number.isSafeInteger(candidate) && candidate >= 0 && candidate <= 100) value = candidate;
    else if (raw) console.warn("invalid_welcome_credits_using_default");
  } catch (error) {
    console.error("remote_config_fetch_failed_using_default", { error: error instanceof Error ? error.message : "unknown" });
  }

  cachedWelcomeCredits = { value, expiresAt: now + cacheDurationMs };
  return value;
}

export async function analysisRuntimeConfiguration(): Promise<RuntimeConfiguration> {
  const now = Date.now();
  if (cachedRuntimeConfiguration && cachedRuntimeConfiguration.expiresAt > now) return cachedRuntimeConfiguration.value;
  const template = await getRemoteConfig().getTemplate();
  const raw = Object.fromEntries(Object.entries(template.parameters).map(([key, parameter]) => {
    const value = parameter.defaultValue;
    if (!value || !("value" in value)) return [key, undefined];
    if (value.value === "true") return [key, true];
    if (value.value === "false") return [key, false];
    return [key, value.value];
  }));
  const value = validateRuntimeConfiguration(raw);
  cachedRuntimeConfiguration = { value, expiresAt: now + cacheDurationMs };
  return value;
}

export interface ApiFootballSettings { enabled: boolean; leagueIds: number[] }
let cachedApiFootball: { value: ApiFootballSettings; expiresAt: number } | undefined;

/** Remote Config `provider_api_football_enabled` (default off) and `api_football_league_ids` (JSON array). */
export async function apiFootballSettings(): Promise<ApiFootballSettings> {
  const now = Date.now();
  if (cachedApiFootball && cachedApiFootball.expiresAt > now) return cachedApiFootball.value;
  let value: ApiFootballSettings = { enabled: false, leagueIds: parseLeagueAllowlist(undefined) };
  try {
    const template = await getRemoteConfig().getTemplate();
    const enabled = template.parameters.provider_api_football_enabled?.defaultValue;
    const leagues = template.parameters.api_football_league_ids?.defaultValue;
    value = {
      enabled: Boolean(enabled && "value" in enabled && enabled.value === "true"),
      leagueIds: parseLeagueAllowlist(leagues && "value" in leagues ? leagues.value : undefined),
    };
  } catch (error) {
    console.error("remote_config_fetch_failed_using_default", { error: error instanceof Error ? error.message : "unknown" });
  }
  cachedApiFootball = { value, expiresAt: now + cacheDurationMs };
  return value;
}
