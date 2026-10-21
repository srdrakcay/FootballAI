import type { SupportedLocale } from "./locales.js";

/** Certainty and betting-call phrases the product never shows, per output language. */
export const prohibitedPatterns: Readonly<Record<SupportedLocale, readonly RegExp[]>> = {
  en: [/\bguaranteed?\b/i, /\bcertain (result|win)\b/i, /\bbet (on|now)\b/i, /\bsure win\b/i, /\block of the\b/i],
  tr: [/\bgaranti/i, /\bkesin (sonuç|kazan|galibiyet)/i, /\bbahis (yap|oyna|öner)/i, /\bkesinlikle kazan/i, /\bbanko\b/i],
  de: [/\bgarantiert?\b/i, /\bsicherer? sieg\b/i, /\bwette (jetzt|auf)\b/i, /\bsicheres ergebnis\b/i],
  es: [/\bgarantizad[oa]\b/i, /\bresultado seguro\b/i, /\bapuesta (por|ahora)\b/i, /\bvictoria segura\b/i],
  fr: [/\bgaranti[e]?\b/i, /\brésultat certain\b/i, /\bpariez (sur|maintenant)\b/i, /\bvictoire certaine\b/i],
};

export function violatesLanguagePolicy(locale: SupportedLocale, text: string): boolean {
  return prohibitedPatterns[locale].some((pattern) => pattern.test(text));
}
