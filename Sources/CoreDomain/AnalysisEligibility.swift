import Foundation

public enum ConnectivityStatus: Sendable { case online, offline }

public protocol ConnectivityProviding: Sendable { func current() async -> ConnectivityStatus }

public actor StaticConnectivityProvider: ConnectivityProviding {
    private var status: ConnectivityStatus
    public init(status: ConnectivityStatus) { self.status = status }
    public func current() -> ConnectivityStatus { status }
    public func set(_ status: ConnectivityStatus) { self.status = status }
}

public enum AnalysisIneligibilityReason: Equatable, Sendable {
    case generationDisabled
    case unsupportedCompetition
    case fixtureStatus(FixtureStatus)
    case kickoffReached
    case offline
    case snapshotMissing
    case snapshotMismatch
    case snapshotStale
    case dataInsufficient
    case quotaExhausted(resetAt: Date)
}

public enum AnalysisEligibility: Equatable, Sendable {
    case eligible
    case ineligible(AnalysisIneligibilityReason)
    public var canGenerate: Bool { if case .eligible = self { true } else { false } }
}

public struct AnalysisEligibilityPolicy: Sendable {
    public init() {}

    public func evaluate(
        fixture: Fixture,
        input: AnalysisInputSummary?,
        configuration: AppConfiguration,
        quota: QuotaStatus,
        connectivity: ConnectivityStatus,
        now: Date,
        snapshotFreshnessLimit: TimeInterval
    ) -> AnalysisEligibility {
        guard configuration.features.analysisGenerationEnabled else { return .ineligible(.generationDisabled) }
        guard configuration.supportedLeagues.contains(fixture.competition.id) else { return .ineligible(.unsupportedCompetition) }
        guard fixture.status.acceptsNewAnalysis else { return .ineligible(.fixtureStatus(fixture.status)) }
        guard fixture.kickoffAt > now else { return .ineligible(.kickoffReached) }
        guard connectivity == .online else { return .ineligible(.offline) }
        guard let input, let expectedSnapshotID = fixture.latestSnapshotID else { return .ineligible(.snapshotMissing) }
        guard input.snapshotID == expectedSnapshotID else { return .ineligible(.snapshotMismatch) }
        guard input.capturedAt <= now, now.timeIntervalSince(input.capturedAt) <= max(0, snapshotFreshnessLimit), !input.availability.values.contains(.stale) else {
            return .ineligible(.snapshotStale)
        }
        guard input.availability.values.contains(.available) else { return .ineligible(.dataInsufficient) }
        if let remaining = quota.remaining, remaining <= 0 { return .ineligible(.quotaExhausted(resetAt: quota.resetsAt)) }
        return .eligible
    }
}
