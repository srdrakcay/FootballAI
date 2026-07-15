import { createHash } from "node:crypto";

export interface AnalysisVersionTuple {
  fixtureKey: string; fixtureVersion: number; snapshotVersion: number; contentHash: string;
  schemaVersion: string; promptVersion: string; modelVersion: string;
}

export function analysisVersionId(tuple: AnalysisVersionTuple): string {
  const canonical = [tuple.fixtureKey, tuple.fixtureVersion, tuple.snapshotVersion, tuple.contentHash, tuple.schemaVersion, tuple.promptVersion, tuple.modelVersion].join("\u001f");
  return createHash("sha256").update(canonical).digest("hex");
}
