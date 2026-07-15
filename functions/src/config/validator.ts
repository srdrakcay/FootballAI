export interface RuntimeConfiguration {
  featureAnalysisGenerationEnabled: boolean;
  freeMonthlyUniqueViews: number;
  analysisLockLeaseSeconds: number;
  schemaVersion: string;
  promptVersion: string;
  modelAlias: string;
}

const allowedSchemaVersions = new Set(["2.0"]);
const allowedPromptVersions = new Set(["football-v2.1.0"]);
const allowedModelAliases = new Set(["gemini-flash-default"]);
const clamp = (value: number, minimum: number, maximum: number) => Math.min(maximum, Math.max(minimum, Math.trunc(value)));

export function validateRuntimeConfiguration(raw: Readonly<Record<string, unknown>>): RuntimeConfiguration {
  const schemaVersion = String(raw.analysis_schema_version ?? "2.0");
  const promptVersion = String(raw.analysis_prompt_version ?? "football-v2.1.0");
  const modelAlias = String(raw.analysis_model_alias ?? "gemini-flash-default");
  if (!allowedSchemaVersions.has(schemaVersion) || !allowedPromptVersions.has(promptVersion) || !allowedModelAliases.has(modelAlias)) {
    throw new Error("CONFIG_ALLOWLIST_REJECTED");
  }
  return {
    featureAnalysisGenerationEnabled: raw.feature_analysis_generation_enabled === true,
    freeMonthlyUniqueViews: clamp(Number(raw.free_monthly_unique_views ?? 1), 0, 20),
    analysisLockLeaseSeconds: clamp(Number(raw.analysis_lock_lease_seconds ?? 90), 30, 180),
    schemaVersion, promptVersion, modelAlias,
  };
}
