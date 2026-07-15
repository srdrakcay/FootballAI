import { getRemoteConfig } from "firebase-admin/remote-config";

const cacheDurationMs = 60_000;
let cachedAnalysisCreditCost: { value: number; expiresAt: number } | undefined;

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
