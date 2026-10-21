export const supportedLocales = ["tr", "en", "de", "es", "fr"] as const;
export type SupportedLocale = (typeof supportedLocales)[number];

const localeSet: ReadonlySet<string> = new Set(supportedLocales);

export function isSupportedLocale(value: unknown): value is SupportedLocale {
  return typeof value === "string" && localeSet.has(value);
}

export function resolveLocale(value: unknown, fallback: SupportedLocale = "en"): SupportedLocale {
  if (isSupportedLocale(value)) return value;
  if (typeof value === "string") {
    const base = value.toLowerCase().replace("_", "-").split("-")[0];
    if (isSupportedLocale(base)) return base;
  }
  return fallback;
}

export const localeDisplayName: Readonly<Record<SupportedLocale, string>> = {
  tr: "Turkish",
  en: "English",
  de: "German",
  es: "Spanish",
  fr: "French",
};
