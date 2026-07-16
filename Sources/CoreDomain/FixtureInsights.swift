import Foundation

public struct FixtureInsights: Codable, Hashable, Sendable {
    public let fixtureKey: FixtureKey
    public let dataSnapshotAt: String
    public let recentForm: TeamFormPair?
    public let headToHead: [FixtureInsightMatch]
    public let standings: TeamStandingPair?
    public let unavailableSections: [String]

    public init(
        fixtureKey: FixtureKey,
        dataSnapshotAt: String,
        recentForm: TeamFormPair?,
        headToHead: [FixtureInsightMatch],
        standings: TeamStandingPair?,
        unavailableSections: [String]
    ) {
        self.fixtureKey = fixtureKey
        self.dataSnapshotAt = dataSnapshotAt
        self.recentForm = recentForm
        self.headToHead = headToHead
        self.standings = standings
        self.unavailableSections = unavailableSections
    }

    private enum CodingKeys: String, CodingKey {
        case fixtureKey, dataSnapshotAt, recentForm, headToHead, standings, unavailableSections
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fixtureKey = FixtureKey(rawValue: try container.decode(String.self, forKey: .fixtureKey))
        dataSnapshotAt = try container.decode(String.self, forKey: .dataSnapshotAt)
        recentForm = try container.decodeIfPresent(TeamFormPair.self, forKey: .recentForm)
        headToHead = try container.decode([FixtureInsightMatch].self, forKey: .headToHead)
        standings = try container.decodeIfPresent(TeamStandingPair.self, forKey: .standings)
        unavailableSections = try container.decode([String].self, forKey: .unavailableSections)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fixtureKey.rawValue, forKey: .fixtureKey)
        try container.encode(dataSnapshotAt, forKey: .dataSnapshotAt)
        try container.encodeIfPresent(recentForm, forKey: .recentForm)
        try container.encode(headToHead, forKey: .headToHead)
        try container.encodeIfPresent(standings, forKey: .standings)
        try container.encode(unavailableSections, forKey: .unavailableSections)
    }
}

public struct TeamFormPair: Codable, Hashable, Sendable {
    public let home: TeamRecentForm
    public let away: TeamRecentForm
    public init(home: TeamRecentForm, away: TeamRecentForm) {
        self.home = home
        self.away = away
    }
}

public struct TeamRecentForm: Codable, Hashable, Sendable {
    public let matches: [FixtureInsightMatch]
    public let wins: Int
    public let draws: Int
    public let losses: Int
    public let goalsFor: Int
    public let goalsAgainst: Int
    public let form: [String]

    public init(matches: [FixtureInsightMatch], wins: Int, draws: Int, losses: Int, goalsFor: Int, goalsAgainst: Int, form: [String]) {
        self.matches = matches
        self.wins = wins
        self.draws = draws
        self.losses = losses
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.form = form
    }
}

public struct TeamStandingPair: Codable, Hashable, Sendable {
    public let home: TeamStanding
    public let away: TeamStanding
    public init(home: TeamStanding, away: TeamStanding) {
        self.home = home
        self.away = away
    }
}

public struct TeamStanding: Codable, Hashable, Sendable {
    public let position: Int?
    public let playedGames: Int?
    public let form: String?
    public let won: Int?
    public let draw: Int?
    public let lost: Int?
    public let points: Int?
    public let goalsFor: Int?
    public let goalsAgainst: Int?
    public let goalDifference: Int?

    public init(position: Int?, playedGames: Int?, form: String?, won: Int?, draw: Int?, lost: Int?, points: Int?, goalsFor: Int?, goalsAgainst: Int?, goalDifference: Int?) {
        self.position = position
        self.playedGames = playedGames
        self.form = form
        self.won = won
        self.draw = draw
        self.lost = lost
        self.points = points
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.goalDifference = goalDifference
    }
}

public struct FixtureInsightMatch: Codable, Hashable, Sendable, Identifiable {
    public var id: String { "\(matchID ?? 0)-\(utcDate ?? "")-\(homeTeamID ?? 0)-\(awayTeamID ?? 0)" }
    public let matchID: Int?
    public let utcDate: String?
    public let homeTeamID: Int?
    public let homeTeamName: String?
    public let awayTeamID: Int?
    public let awayTeamName: String?
    public let homeGoals: Int?
    public let awayGoals: Int?

    enum CodingKeys: String, CodingKey {
        case matchID = "id"
        case utcDate, homeTeamID = "homeTeamId", homeTeamName
        case awayTeamID = "awayTeamId", awayTeamName, homeGoals, awayGoals
    }

    public init(matchID: Int?, utcDate: String?, homeTeamID: Int?, homeTeamName: String?, awayTeamID: Int?, awayTeamName: String?, homeGoals: Int?, awayGoals: Int?) {
        self.matchID = matchID
        self.utcDate = utcDate
        self.homeTeamID = homeTeamID
        self.homeTeamName = homeTeamName
        self.awayTeamID = awayTeamID
        self.awayTeamName = awayTeamName
        self.homeGoals = homeGoals
        self.awayGoals = awayGoals
    }
}
