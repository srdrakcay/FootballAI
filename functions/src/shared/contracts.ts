export const analysisStates = [
  "not_started", "queued", "generating", "validating", "ready",
  "failed_retryable", "failed_permanent", "stale", "cancelled", "expired",
] as const;

export type AnalysisState = (typeof analysisStates)[number];

export interface RequestAnalysisPayload {
  fixtureKey: string;
  locale: "tr" | "en" | "de" | "es" | "fr";
  clientRequestId: string;
  acceptedDisclaimerVersion: string;
}

export interface RequestAnalysisResponse {
  requestId: string;
  analysisId?: string;
  state: AnalysisState;
}

export class PublicError extends Error {
  constructor(public readonly code: string, public readonly referenceId: string) {
    super(code);
  }
}
