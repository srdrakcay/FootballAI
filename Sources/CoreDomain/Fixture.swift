import Foundation

public enum FixtureStatus: String, Codable, CaseIterable, Sendable {
    case scheduled, timed, postponed, suspended, cancelled, inProgress = "in_progress", finished, awarded

    public var acceptsNewAnalysis: Bool {
        switch self {
        case .scheduled, .timed, .postponed: true
        case .suspended, .cancelled, .inProgress, .finished, .awarded: false
        }
    }
}

public struct Team: Codable, Hashable, Sendable, Identifiable {
    public let id: TeamID
    public let name: String
    public init(id: TeamID, name: String) { self.id = id; self.name = name }
}

public struct Competition: Codable, Hashable, Sendable, Identifiable {
    public let id: CompetitionID
    public let name: String
    /// Provider area (country or continent), used to group competitions the app has no code for.
    public let areaName: String?
    public init(id: CompetitionID, name: String, areaName: String? = nil) { self.id = id; self.name = name; self.areaName = areaName }
}

public struct Fixture: Codable, Hashable, Sendable, Identifiable {
    public var id: FixtureKey { key }
    public let key: FixtureKey
    public let version: Int
    public let competition: Competition
    public let homeTeam: Team
    public let awayTeam: Team
    public let kickoffAt: Date
    public let status: FixtureStatus
    public let latestSnapshotID: SnapshotID?
    /// `false` for browse-only fixtures (leagues listed without the data an AI analysis needs). `nil` = supported.
    public let analysisSupported: Bool?
    public var supportsAnalysis: Bool { analysisSupported ?? true }

    public init(key: FixtureKey, version: Int, competition: Competition, homeTeam: Team, awayTeam: Team, kickoffAt: Date, status: FixtureStatus, latestSnapshotID: SnapshotID?, analysisSupported: Bool? = nil) {
        self.analysisSupported = analysisSupported
        self.key = key; self.version = version; self.competition = competition
        self.homeTeam = homeTeam; self.awayTeam = awayTeam; self.kickoffAt = kickoffAt
        self.status = status; self.latestSnapshotID = latestSnapshotID
    }
}

public struct FixtureFilter: Sendable, Equatable {
    public let competitionIDs: Set<CompetitionID>
    public let from: Date
    public let through: Date
    public init(competitionIDs: Set<CompetitionID> = [], from: Date, through: Date) {
        self.competitionIDs = competitionIDs; self.from = from; self.through = through
    }
}

public enum DataAvailability: String, Codable, CaseIterable, Sendable {
    case available, unavailable, stale
}

public struct AnalysisInputSummary: Codable, Hashable, Sendable {
    public let snapshotID: SnapshotID
    public let snapshotVersion: Int
    public let capturedAt: Date
    public let availability: [String: DataAvailability]
    public init(snapshotID: SnapshotID, snapshotVersion: Int, capturedAt: Date, availability: [String: DataAvailability]) {
        self.snapshotID = snapshotID; self.snapshotVersion = snapshotVersion
        self.capturedAt = capturedAt; self.availability = availability
    }
}
