import Foundation

public enum ProbabilityValidationError: Error, Equatable, Sendable {
    case outOfRange
    case invalidTotal(expected: Int, actual: Int)
    case duplicateScoreline
}

public struct MatchResultProbabilities: Codable, Equatable, Sendable {
    public let home: Int; public let draw: Int; public let away: Int
    public init(home: Int, draw: Int, away: Int) throws {
        try Self.validate([home, draw, away]); self.home = home; self.draw = draw; self.away = away
    }
    private static func validate(_ values: [Int]) throws {
        guard values.allSatisfy((0...100).contains) else { throw ProbabilityValidationError.outOfRange }
        guard values.reduce(0, +) == 100 else { throw ProbabilityValidationError.invalidTotal(expected: 100, actual: values.reduce(0, +)) }
    }
}

public struct BinaryProbabilities: Codable, Equatable, Sendable {
    public let yes: Int; public let no: Int
    public init(yes: Int, no: Int) throws {
        guard (0...100).contains(yes), (0...100).contains(no) else { throw ProbabilityValidationError.outOfRange }
        guard yes + no == 100 else { throw ProbabilityValidationError.invalidTotal(expected: 100, actual: yes + no) }
        self.yes = yes; self.no = no
    }
}

public struct ScorelineProbability: Codable, Hashable, Sendable {
    public let home: Int; public let away: Int; public let percentage: Int
    public init(home: Int, away: Int, percentage: Int) throws {
        guard home >= 0, away >= 0, (0...100).contains(percentage) else { throw ProbabilityValidationError.outOfRange }
        self.home = home; self.away = away; self.percentage = percentage
    }
}

public struct ProbabilityMarkets: Codable, Equatable, Sendable {
    public let matchResult: MatchResultProbabilities
    public let goalsOver25: BinaryProbabilities
    public let bothTeamsScore: BinaryProbabilities
    public let likelyScores: [ScorelineProbability]
    public let otherScoresPercentage: Int

    public init(matchResult: MatchResultProbabilities, goalsOver25: BinaryProbabilities, bothTeamsScore: BinaryProbabilities, likelyScores: [ScorelineProbability], otherScoresPercentage: Int) throws {
        guard Set(likelyScores.map { "\($0.home):\($0.away)" }).count == likelyScores.count else { throw ProbabilityValidationError.duplicateScoreline }
        let total = likelyScores.reduce(0) { $0 + $1.percentage } + otherScoresPercentage
        guard (0...100).contains(otherScoresPercentage) else { throw ProbabilityValidationError.outOfRange }
        guard total == 100 else { throw ProbabilityValidationError.invalidTotal(expected: 100, actual: total) }
        self.matchResult = matchResult; self.goalsOver25 = goalsOver25
        self.bothTeamsScore = bothTeamsScore; self.likelyScores = likelyScores
        self.otherScoresPercentage = otherScoresPercentage
    }
}

public enum ConfidenceLevel: String, Codable, Sendable { case low, medium, high }
public struct Confidence: Codable, Equatable, Sendable {
    public let level: ConfidenceLevel; public let scorePercentage: Int
    public init(level: ConfidenceLevel, scorePercentage: Int) throws {
        guard (0...100).contains(scorePercentage) else { throw ProbabilityValidationError.outOfRange }
        self.level = level; self.scorePercentage = scorePercentage
    }
}

public struct Rationale: Codable, Equatable, Sendable, Identifiable {
    public var id: String { code }
    public let code: String; public let text: String; public let evidenceRefs: [String]
    public init(code: String, text: String, evidenceRefs: [String]) { self.code = code; self.text = text; self.evidenceRefs = evidenceRefs }
}

public enum ModerationStatus: String, Codable, Sendable { case passed }

public struct Analysis: Codable, Equatable, Sendable, Identifiable {
    public let id: AnalysisID; public let fixtureKey: FixtureKey; public let fixtureVersion: Int
    public let snapshotID: SnapshotID; public let snapshotVersion: Int
    public let schemaVersion: String; public let promptVersion: String; public let modelVersion: String
    public let generatedAt: Date; public let validUntil: Date; public let language: SupportedLocale
    public let markets: ProbabilityMarkets; public let confidence: Confidence
    public let rationale: [Rationale]; public let dataAvailability: [String: DataAvailability]
    public let limitations: [String]; public let moderationStatus: ModerationStatus

    public init(id: AnalysisID, fixtureKey: FixtureKey, fixtureVersion: Int, snapshotID: SnapshotID, snapshotVersion: Int, schemaVersion: String, promptVersion: String, modelVersion: String, generatedAt: Date, validUntil: Date, language: SupportedLocale, markets: ProbabilityMarkets, confidence: Confidence, rationale: [Rationale], dataAvailability: [String: DataAvailability], limitations: [String], moderationStatus: ModerationStatus) {
        self.id = id; self.fixtureKey = fixtureKey; self.fixtureVersion = fixtureVersion
        self.snapshotID = snapshotID; self.snapshotVersion = snapshotVersion; self.schemaVersion = schemaVersion
        self.promptVersion = promptVersion; self.modelVersion = modelVersion; self.generatedAt = generatedAt
        self.validUntil = validUntil; self.language = language; self.markets = markets
        self.confidence = confidence; self.rationale = rationale; self.dataAvailability = dataAvailability
        self.limitations = limitations; self.moderationStatus = moderationStatus
    }
}
