import Foundation

public struct FeatureFlags: Equatable, Sendable {
    public let analysisGenerationEnabled: Bool
    public let cachedAnalysisReadEnabled: Bool
    public let premiumEnabled: Bool
    public init(analysisGenerationEnabled: Bool, cachedAnalysisReadEnabled: Bool, premiumEnabled: Bool) {
        self.analysisGenerationEnabled = analysisGenerationEnabled
        self.cachedAnalysisReadEnabled = cachedAnalysisReadEnabled
        self.premiumEnabled = premiumEnabled
    }
}

public struct PlanLimits: Equatable, Sendable {
    public let freeMonthlyUniqueViews: Int
    public let freeHistoryDays: Int
    public let premiumHistoryDays: Int
    public init(freeMonthlyUniqueViews: Int, freeHistoryDays: Int, premiumHistoryDays: Int) {
        self.freeMonthlyUniqueViews = min(max(freeMonthlyUniqueViews, 0), 20)
        self.freeHistoryDays = min(max(freeHistoryDays, 1), 90)
        self.premiumHistoryDays = min(max(premiumHistoryDays, 30), 730)
    }
}

public struct AppConfiguration: Equatable, Sendable {
    public let features: FeatureFlags
    public let supportedLeagues: Set<CompetitionID>
    public let planLimits: PlanLimits
    public let analysisCreditCost: Int
    public let revenueCatPublicSDKKeyIOS: String
    public init(features: FeatureFlags, supportedLeagues: Set<CompetitionID>, planLimits: PlanLimits, analysisCreditCost: Int = 1, revenueCatPublicSDKKeyIOS: String = "") {
        self.features = features; self.supportedLeagues = supportedLeagues; self.planLimits = planLimits
        self.analysisCreditCost = min(max(analysisCreditCost, 1), 100)
        self.revenueCatPublicSDKKeyIOS = revenueCatPublicSDKKeyIOS
    }

    public static let safeDefaults = AppConfiguration(
        features: .init(analysisGenerationEnabled: false, cachedAnalysisReadEnabled: true, premiumEnabled: false),
        supportedLeagues: Set(["PL", "PD", "SA", "BL1", "FL1", "UCL"].map { CompetitionID(rawValue: $0) }),
        planLimits: .init(freeMonthlyUniqueViews: 1, freeHistoryDays: 30, premiumHistoryDays: 365),
        analysisCreditCost: 1
    )
}

public enum AnalysisState: String, Codable, CaseIterable, Sendable {
    case notStarted = "not_started", queued, generating, validating, ready
    case failedRetryable = "failed_retryable", failedPermanent = "failed_permanent"
    case stale, cancelled, expired
}

public struct AnalysisRequest: Codable, Equatable, Sendable, Identifiable {
    public let id: AnalysisRequestID; public let analysisID: AnalysisID?; public let state: AnalysisState
    public init(id: AnalysisRequestID, analysisID: AnalysisID?, state: AnalysisState) { self.id = id; self.analysisID = analysisID; self.state = state }
}

public enum Plan: String, Codable, Sendable { case free, premium }
public struct PlanEntitlement: Codable, Equatable, Sendable {
    public let plan: Plan; public let expiresAt: Date?
    public init(plan: Plan, expiresAt: Date?) { self.plan = plan; self.expiresAt = expiresAt }
}
public struct QuotaStatus: Codable, Equatable, Sendable {
    public let remaining: Int?; public let resetsAt: Date
    public init(remaining: Int?, resetsAt: Date) { self.remaining = remaining; self.resetsAt = resetsAt }
}

public struct RequestAnalysisCommand: Sendable, Equatable {
    public let fixtureKey: FixtureKey; public let requestedLocale: SupportedLocale
    public let clientRequestID: UUID; public let acceptedDisclaimerVersion: String
    public init(fixtureKey: FixtureKey, requestedLocale: SupportedLocale, clientRequestID: UUID, acceptedDisclaimerVersion: String) {
        self.fixtureKey = fixtureKey; self.requestedLocale = requestedLocale
        self.clientRequestID = clientRequestID; self.acceptedDisclaimerVersion = acceptedDisclaimerVersion
    }
}
