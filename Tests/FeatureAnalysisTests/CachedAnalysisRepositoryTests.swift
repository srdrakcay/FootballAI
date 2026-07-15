import CoreDomain
import CorePersistence
import FeatureAnalysis
import Foundation
import XCTest

final class CachedAnalysisRepositoryTests: XCTestCase {
    func testOfflineRequestFailsButValidCachedReadSucceeds() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("footballai-repository-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileAnalysisCache(directory: directory)
        let analysis = try makeAnalysis(now: now)
        try await cache.store(analysis)
        let repository = CachedAnalysisRepository(remote: InMemoryAnalysisRepository(), cache: cache, connectivity: StaticConnectivityProvider(status: .offline), now: { now })

        let cached = try await repository.analysis(id: analysis.id, locale: .en)
        XCTAssertEqual(cached, analysis)
        let command = RequestAnalysisCommand(fixtureKey: analysis.fixtureKey, requestedLocale: .en, clientRequestID: UUID(), acceptedDisclaimerVersion: "legal_v1")
        do { _ = try await repository.request(command); XCTFail("Offline generation must fail") }
        catch { XCTAssertEqual(error as? DomainError, .networkOffline) }
    }

    func testLocaleIsPartOfCacheIdentity() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("footballai-locale-cache-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileAnalysisCache(directory: directory)
        let analysis = try makeAnalysis(now: now)
        try await cache.store(analysis)
        let english = await cache.value(for: analysis.id, locale: .en, now: now)
        let turkish = await cache.value(for: analysis.id, locale: .tr, now: now)
        XCTAssertNotNil(english)
        XCTAssertNil(turkish)
    }

    private func makeAnalysis(now: Date) throws -> Analysis {
        let match = try MatchResultProbabilities(home: 40, draw: 30, away: 30)
        let binary = try BinaryProbabilities(yes: 50, no: 50)
        let score = try ScorelineProbability(home: 1, away: 1, percentage: 10)
        let markets = try ProbabilityMarkets(matchResult: match, goalsOver25: binary, bothTeamsScore: binary, likelyScores: [score], otherScoresPercentage: 90)
        return Analysis(id: .init(rawValue: "analysis"), fixtureKey: .init(rawValue: "fixture"), fixtureVersion: 1, snapshotID: .init(rawValue: "snapshot"), snapshotVersion: 1, schemaVersion: "2.0", promptVersion: "prompt", modelVersion: "model", generatedAt: now, validUntil: now.addingTimeInterval(3_600), language: .en, markets: markets, confidence: try .init(level: .medium, scorePercentage: 50), rationale: [], dataAvailability: [:], limitations: [], moderationStatus: .passed)
    }
}
