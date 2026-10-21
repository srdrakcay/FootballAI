/**
 * Gemini's response-schema subset has no `pattern` support, so the `sections.<name>` format of
 * `rationale[].evidenceRefs` is only a prompt instruction to the model. Models drift ("recentForm",
 * "Recent form", "sections.recentForm.last5"). This maps those variants back to the canonical
 * `sections.<name>` and drops anything that does not name a known section. It never invents a
 * section: availability is still enforced afterwards by the validator (EVIDENCE_UNAVAILABLE).
 */
const sectionNames = ["recentForm", "headToHead", "standings", "squadAvailability", "lineups", "weather"] as const;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function canonicalSectionRef(reference: unknown): string | null {
  if (typeof reference !== "string") return null;
  const key = (reference
    .trim()
    .toLowerCase()
    .replace(/^sections?[.\/:]/, "")
    .split(/[.\/:\[]/)[0] ?? "")
    .replace(/[\s_-]/g, "");
  const match = sectionNames.find((name) => name.toLowerCase() === key);
  return match ? `sections.${match}` : null;
}

export function normalizeEvidenceRefs(raw: unknown): unknown {
  if (!isRecord(raw) || !Array.isArray(raw.rationale)) return raw;
  const rationale = raw.rationale.map((item) => {
    if (!isRecord(item) || !Array.isArray(item.evidenceRefs)) return item;
    const refs = [...new Set(item.evidenceRefs.map(canonicalSectionRef).filter((value): value is string => value !== null))];
    return { ...item, evidenceRefs: refs };
  });
  return { ...raw, rationale };
}
