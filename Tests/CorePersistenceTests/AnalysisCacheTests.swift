import CoreDomain
import CorePersistence
import Foundation
import XCTest

final class AnalysisCacheTests: XCTestCase {
    func testReadyAnalysisRoundTripsAndExpires() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("footballai-cache-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileAnalysisCache(directory: directory)
        let now = Date(timeIntervalSince1970: 1_000)
        let analysis = try makeAnalysis(now: now)
        try await cache.store(analysis)
        let cached = await cache.value(for: analysis.id, locale: .en, now: now)
        XCTAssertEqual(cached, analysis)
        let expired = await cache.value(for: analysis.id, locale: .en, now: now.addingTimeInterval(7_201))
        XCTAssertNil(expired)
    }

    private func makeAnalysis(now: Date) throws -> Analysis {
        let match = try MatchResultProbabilities(home: 40, draw: 30, away: 30)
        let binary = try BinaryProbabilities(yes: 50, no: 50)
        let score = try ScorelineProbability(home: 1, away: 1, percentage: 10)
        let markets = try ProbabilityMarkets(matchResult: match, goalsOver25: binary, bothTeamsScore: binary, likelyScores: [score], otherScoresPercentage: 90)
        return Analysis(id: .init(rawValue: "analysis/path-safe"), fixtureKey: .init(rawValue: "fixture"), fixtureVersion: 1, snapshotID: .init(rawValue: "snapshot"), snapshotVersion: 1, schemaVersion: "2.0", promptVersion: "prompt", modelVersion: "model", generatedAt: now, validUntil: now.addingTimeInterval(7_200), language: .en, markets: markets, confidence: try .init(level: .medium, scorePercentage: 50), rationale: [], dataAvailability: [:], limitations: [], moderationStatus: .passed)
    }
}
