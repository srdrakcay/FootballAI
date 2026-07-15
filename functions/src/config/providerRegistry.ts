export const modelAliases = {
  "gemini-flash-default": { provider: "google", model: "gemini-3.5-flash" },
} as const;

export const footballProvider = {
  alias: "api-football-v3",
  baseURL: "https://v3.football.api-sports.io",
  forbiddenEndpoints: ["predictions", "odds"],
} as const;
