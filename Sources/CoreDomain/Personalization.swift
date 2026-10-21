import Foundation

public enum AnalysisStyle: String, Codable, CaseIterable, Sendable {
    case brief, balanced, deep
}

public enum FocusMarket: String, Codable, CaseIterable, Sendable {
    case matchResult, goals, bothTeamsScore, scorelines
}

public struct FavoriteTeam: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

/// What the reader told us about themselves. Shapes the language, depth and angle of every analysis.
public struct AIProfile: Codable, Equatable, Sendable {
    public var favoriteTeam: FavoriteTeam?
    public var competitionIds: [String]
    public var style: AnalysisStyle
    public var focusMarkets: [FocusMarket]

    public init(favoriteTeam: FavoriteTeam? = nil, competitionIds: [String] = [], style: AnalysisStyle = .balanced, focusMarkets: [FocusMarket] = [.matchResult, .goals]) {
        self.favoriteTeam = favoriteTeam
        self.competitionIds = competitionIds
        self.style = style
        self.focusMarkets = focusMarkets.isEmpty ? [.matchResult] : focusMarkets
    }

    public static let `default` = AIProfile()

    private enum CodingKeys: String, CodingKey { case favoriteTeam, competitionIds, style, focusMarkets }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            favoriteTeam: try container.decodeIfPresent(FavoriteTeam.self, forKey: .favoriteTeam),
            competitionIds: try container.decodeIfPresent([String].self, forKey: .competitionIds) ?? [],
            style: (try? container.decodeIfPresent(AnalysisStyle.self, forKey: .style)) ?? .balanced,
            focusMarkets: ((try? container.decodeIfPresent([String].self, forKey: .focusMarkets)) ?? [])
                .compactMap(FocusMarket.init(rawValue:))
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(favoriteTeam, forKey: .favoriteTeam)
        try container.encode(competitionIds, forKey: .competitionIds)
        try container.encode(style, forKey: .style)
        try container.encode(focusMarkets, forKey: .focusMarkets)
    }
}

public protocol AIProfileRepository: Sendable {
    func load() async throws -> AIProfile?
    func save(_ profile: AIProfile, locale: SupportedLocale) async throws
}

public actor InMemoryAIProfileRepository: AIProfileRepository {
    private var value: AIProfile?
    public init(profile: AIProfile? = nil) { value = profile }
    public func load() -> AIProfile? { value }
    public func save(_ profile: AIProfile, locale: SupportedLocale) { value = profile }
}

// MARK: - Unlocked analysis (server payload)

/// The shared, language-neutral layer: every number in the analysis comes from here.
public struct MatchAnalysis: Codable, Equatable, Sendable {
    public struct ResultMarket: Codable, Equatable, Sendable { public let homePct: Int; public let drawPct: Int; public let awayPct: Int }
    public struct OverUnder: Codable, Equatable, Sendable { public let overPct: Int; public let underPct: Int }
    public struct YesNo: Codable, Equatable, Sendable { public let yesPct: Int; public let noPct: Int }
    public struct Scoreline: Codable, Equatable, Sendable, Identifiable {
        public let home: Int; public let away: Int; public let pct: Int
        public var id: String { "\(home)-\(away)" }
    }
    public struct Markets: Codable, Equatable, Sendable {
        public let matchResult: ResultMarket
        public let goals25: OverUnder
        public let bothTeamsScore: YesNo
        public let likelyScores: [Scoreline]
        public let otherScoresPct: Int
    }
    public struct ConfidenceValue: Codable, Equatable, Sendable { public let level: ConfidenceLevel; public let scorePct: Int }

    public let analysisId: String
    public let fixtureKey: String
    public let generatedAt: String
    public let validUntil: String
    public let markets: Markets
    public let confidence: ConfidenceValue
    public let limitations: [String]

    public var generatedDate: Date? { ISODate.parse(generatedAt) }
    public var validUntilDate: Date? { ISODate.parse(validUntil) }
}

public enum EvidenceSection: String, Codable, Sendable {
    case recentForm, headToHead, standings, squadAvailability, lineups, weather
}

/// Written for one reader: their language, their depth, their team.
public struct PersonalAnalysis: Codable, Equatable, Sendable {
    public struct KeyFactor: Codable, Equatable, Sendable, Identifiable {
        public let section: EvidenceSection
        public let text: String
        public var id: String { "\(section.rawValue)-\(text)" }
        public init(section: EvidenceSection, text: String) { self.section = section; self.text = text }
    }
    public enum Side: String, Codable, Sendable { case home, away }

    public let headline: String
    public let summary: String
    public let forYou: String?
    public let keyFactors: [KeyFactor]
    public let watchNote: String?
    public let locale: SupportedLocale
    public let favoriteSide: Side?

    public init(headline: String, summary: String, forYou: String?, keyFactors: [KeyFactor], watchNote: String?, locale: SupportedLocale, favoriteSide: Side?) {
        self.headline = headline; self.summary = summary; self.forYou = forYou
        self.keyFactors = keyFactors; self.watchNote = watchNote
        self.locale = locale; self.favoriteSide = favoriteSide
    }
}

public struct UnlockedAnalysis: Equatable, Sendable {
    public let analysis: MatchAnalysis
    public let personal: PersonalAnalysis
    public let wallet: CreditWallet
    public init(analysis: MatchAnalysis, personal: PersonalAnalysis, wallet: CreditWallet) {
        self.analysis = analysis; self.personal = personal; self.wallet = wallet
    }
}

public enum AnalysisAccess: Equatable, Sendable {
    case locked(CreditWallet)
    case unlocked(UnlockedAnalysis)
}

public protocol AnalysisAccessService: Sendable {
    /// Returns the reader's analysis if they unlocked it before. Never charges.
    func open(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> AnalysisAccess
    /// Spends credits (once per fixture) and returns the analysis, generating it if needed.
    func unlock(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> UnlockedAnalysis
}

public enum ISODate {
    public static func parse(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }
}

/// Everything the app needs on launch, delivered by one server round trip.
public struct SessionInfo: Equatable, Sendable {
    public let uid: String
    public let wallet: CreditWallet
    public let aiProfile: AIProfile?
    public init(uid: String, wallet: CreditWallet, aiProfile: AIProfile?) {
        self.uid = uid; self.wallet = wallet; self.aiProfile = aiProfile
    }
}
