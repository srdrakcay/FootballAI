import type { RequestAnalysisPayload, RequestAnalysisResponse } from "../shared/contracts.js";

export interface AuthorizedContext { uid: string; appId: string; correlationId: string }
export interface RequestStore {
  reserveOrJoin(context: AuthorizedContext, payload: RequestAnalysisPayload): Promise<RequestAnalysisResponse>;
}

/**
 * Transactional persistence owns cache identity, lease acquisition and quota reservation.
 * This application service deliberately accepts no prompt, model, quota or provider payload from the client.
 */
export class AnalysisOrchestrator {
  constructor(private readonly requests: RequestStore) {}
  request(context: AuthorizedContext, payload: RequestAnalysisPayload): Promise<RequestAnalysisResponse> {
    return this.requests.reserveOrJoin(context, payload);
  }
}
