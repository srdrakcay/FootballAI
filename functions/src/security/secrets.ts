import { defineSecret } from "firebase-functions/params";
import { SecretManagerServiceClient } from "@google-cloud/secret-manager";

// Secret values are bound only by functions that actively use them.
export const footballDataApiToken = defineSecret("FOOTBALL_DATA_API_TOKEN");
export const revenueCatWebhookAuthorization = defineSecret("REVENUECAT_WEBHOOK_AUTH");
export const geminiApiKey = defineSecret("GEMINI_API_KEY");
export const apiFootballKey = defineSecret("API_FOOTBALL_KEY");

const secretManager = new SecretManagerServiceClient();
const secretCache = new Map<string, { value: string; expiresAt: number }>();

/** Reads versions/latest so a new secret version becomes active without a function deploy. */
export async function rotatingSecret(name: string, cacheDurationMs = 60_000): Promise<string> {
  const cached = secretCache.get(name);
  if (cached && cached.expiresAt > Date.now()) return cached.value;
  const projectID = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT;
  if (!projectID) throw new Error("PROJECT_ID_UNAVAILABLE");
  const [version] = await secretManager.accessSecretVersion({
    name: `projects/${projectID}/secrets/${name}/versions/latest`,
  });
  const value = version.payload?.data?.toString().trim() ?? "";
  if (!value) throw new Error("SECRET_UNAVAILABLE");
  secretCache.set(name, { value, expiresAt: Date.now() + cacheDurationMs });
  return value;
}

export function requiredSecret(secret: ReturnType<typeof defineSecret>): string {
  const value = secret.value();
  if (value.trim().length === 0) throw new Error("SECRET_UNAVAILABLE");
  return value;
}
