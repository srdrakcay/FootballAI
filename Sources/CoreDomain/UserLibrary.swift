import Foundation

public struct AnalysisHistoryItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let fixtureKey: FixtureKey
    public let analysisID: AnalysisID
    public let competitionName: String
    public let homeTeamName: String
    public let awayTeamName: String
    public let kickoffAt: Date
    public let viewedAt: Date
    public let generatedAt: Date
    public let validUntil: Date
    public let homeWinProbability: Int?
    public let drawProbability: Int?
    public let awayWinProbability: Int?

    public init(
        id: String,
        fixtureKey: FixtureKey,
        analysisID: AnalysisID,
        competitionName: String,
        homeTeamName: String,
        awayTeamName: String,
        kickoffAt: Date,
        viewedAt: Date,
        generatedAt: Date,
        validUntil: Date,
        homeWinProbability: Int?,
        drawProbability: Int? = nil,
        awayWinProbability: Int? = nil
    ) {
        self.id = id
        self.fixtureKey = fixtureKey
        self.analysisID = analysisID
        self.competitionName = competitionName
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.kickoffAt = kickoffAt
        self.viewedAt = viewedAt
        self.generatedAt = generatedAt
        self.validUntil = validUntil
        self.homeWinProbability = homeWinProbability
        self.drawProbability = drawProbability
        self.awayWinProbability = awayWinProbability
    }

    /// True when all three outcome probabilities are known (history written by schema v2).
    public var hasFullResult: Bool { homeWinProbability != nil && drawProbability != nil && awayWinProbability != nil }
}

public protocol UserLibraryRepository: Sendable {
    func favoriteFixtureKeys() async throws -> Set<FixtureKey>
    func favoriteFixtures() async throws -> [Fixture]
    func setFavorite(_ fixture: Fixture, isFavorite: Bool) async throws
    func analysisHistory() async throws -> [AnalysisHistoryItem]
}

public actor InMemoryUserLibraryRepository: UserLibraryRepository {
    private var favorites: [FixtureKey: Fixture]
    private var history: [AnalysisHistoryItem]

    public init(favorites: [Fixture] = [], history: [AnalysisHistoryItem] = []) {
        self.favorites = Dictionary(uniqueKeysWithValues: favorites.map { ($0.key, $0) })
        self.history = history
    }

    public func favoriteFixtureKeys() -> Set<FixtureKey> { Set(favorites.keys) }
    public func favoriteFixtures() -> [Fixture] { favorites.values.sorted { $0.kickoffAt < $1.kickoffAt } }

    public func setFavorite(_ fixture: Fixture, isFavorite: Bool) {
        if isFavorite { favorites[fixture.key] = fixture }
        else { favorites.removeValue(forKey: fixture.key) }
    }

    public func analysisHistory() -> [AnalysisHistoryItem] { history }
}
