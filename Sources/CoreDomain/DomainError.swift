import Foundation

public enum DomainError: Error, Equatable, Sendable {
    case authRequired, appCheckFailed, rateLimited(retryAfter: Date?)
    case fixtureNotFound, fixtureIneligible(reason: String), dataInsufficient(missingCodes: [String])
    case analysisStale, quotaExhausted(resetAt: Date), insufficientCredits(balance: Int, required: Int), entitlementUnavailable
    case generationInProgress(requestID: AnalysisRequestID)
    case generationFailedRetryable(retryAfter: Date?), generationFailedPermanent(referenceID: String)
    case configUnavailable, networkOffline, updateRequired, unknown(referenceID: String)
}
