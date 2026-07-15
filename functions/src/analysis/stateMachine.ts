import type { AnalysisState } from "../shared/contracts.js";

const transitions: Readonly<Record<AnalysisState, readonly AnalysisState[]>> = {
  not_started: ["queued", "cancelled"],
  queued: ["generating", "failed_retryable", "failed_permanent", "cancelled", "expired"],
  generating: ["validating", "failed_retryable", "failed_permanent", "cancelled", "expired"],
  validating: ["ready", "failed_retryable", "failed_permanent", "cancelled", "expired"],
  ready: ["stale", "expired"],
  failed_retryable: ["queued", "failed_permanent", "cancelled", "expired"],
  failed_permanent: [],
  stale: ["queued", "expired"],
  cancelled: [],
  expired: [],
};

export function assertTransition(from: AnalysisState, to: AnalysisState): void {
  if (!transitions[from].includes(to)) throw new Error(`INVALID_STATE_TRANSITION:${from}:${to}`);
}
