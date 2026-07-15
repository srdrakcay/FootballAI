export type SectionStatus = "available" | "unavailable" | "stale";
export interface SnapshotSection { status: SectionStatus; observedAt: string | null; data: unknown }
export interface SnapshotForFreshness { dataSnapshotAt: string; sections: Readonly<Record<string, SnapshotSection>> }
export interface FreshnessPolicy { maximumAgeSeconds: Readonly<Record<string, number>>; minimumAvailableSections: number }
export interface FreshnessResult {
  eligible: boolean;
  sections: Readonly<Record<string, SnapshotSection>>;
  availableSectionNames: readonly string[];
  staleSectionNames: readonly string[];
}

export function applyFreshnessPolicy(snapshot: SnapshotForFreshness, policy: FreshnessPolicy, now: Date): FreshnessResult {
  const normalized: Record<string, SnapshotSection> = {};
  const available: string[] = [];
  const stale: string[] = [];

  for (const [name, section] of Object.entries(snapshot.sections)) {
    const maximumAge = boundedMaximumAge(policy.maximumAgeSeconds[name]);
    const observedAt = section.observedAt ? Date.parse(section.observedAt) : Number.NaN;
    const temporallyValid = Number.isFinite(observedAt) && observedAt <= now.getTime() && now.getTime() - observedAt <= maximumAge * 1_000;
    if (section.status === "available" && temporallyValid && section.data !== null) {
      normalized[name] = section; available.push(name);
    } else if (section.status === "available" || section.status === "stale") {
      normalized[name] = { ...section, status: "stale" }; stale.push(name);
    } else {
      normalized[name] = { status: "unavailable", observedAt: section.observedAt, data: null };
    }
  }

  return { eligible: available.length >= Math.max(1, policy.minimumAvailableSections), sections: normalized, availableSectionNames: available, staleSectionNames: stale };
}

/** Only available sections are permitted to cross the model-gateway boundary. */
export function promptSnapshotProjection(snapshot: SnapshotForFreshness, freshness: FreshnessResult): SnapshotForFreshness {
  const allowed = new Set(freshness.availableSectionNames);
  return { dataSnapshotAt: snapshot.dataSnapshotAt, sections: Object.fromEntries(Object.entries(freshness.sections).filter(([name]) => allowed.has(name))) };
}

const boundedMaximumAge = (value: number | undefined) => Math.min(86_400, Math.max(60, Math.trunc(value ?? 3_600)));
