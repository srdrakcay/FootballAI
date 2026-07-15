import CoreDomain
import XCTest

final class EligibilityTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testEligibleSnapshotPasses() {
        XCTAssertEqual(evaluate(), .eligible)
    }

    func testOfflineAndStaleSnapshotFailClosed() {
        XCTAssertEqual(evaluate(connectivity: .offline), .ineligible(.offline))
        XCTAssertEqual(evaluate(snapshotDate: now.addingTimeInterval(-7_200)), .ineligible(.snapshotStale))
    }

    func testQuotaAndFixtureStatusAreAuthoritativeHints() {
        let reset = now.addingTimeInterval(86_400)
        XCTAssertEqual(evaluate(remaining: 0, resetAt: reset), .ineligible(.quotaExhausted(resetAt: reset)))
        XCTAssertEqual(evaluate(status: .inProgress), .ineligible(.fixtureStatus(.inProgress)))
    }

    private func evaluate(status: FixtureStatus = .timed, connectivity: ConnectivityStatus = .online, snapshotDate: Date? = nil, remaining: Int? = 3, resetAt: Date? = nil) -> AnalysisEligibility {
        let competition = Competition(id: .init(rawValue: "UCL"), name: "UCL")
        let team = Team(id: .init(rawValue: "A"), name: "A")
        let snapshotID = SnapshotID(rawValue: "snapshot")
        let fixture = Fixture(key: .init(rawValue: "fixture"), version: 1, competition: competition, homeTeam: team, awayTeam: team, kickoffAt: now.addingTimeInterval(10_000), status: status, latestSnapshotID: snapshotID)
        let configuration = AppConfiguration(features: .init(analysisGenerationEnabled: true, cachedAnalysisReadEnabled: true, premiumEnabled: false), supportedLeagues: [competition.id], planLimits: .init(freeMonthlyUniqueViews: 1, freeHistoryDays: 30, premiumHistoryDays: 365))
        let input = AnalysisInputSummary(snapshotID: snapshotID, snapshotVersion: 1, capturedAt: snapshotDate ?? now.addingTimeInterval(-60), availability: ["recentForm": .available])
        return AnalysisEligibilityPolicy().evaluate(fixture: fixture, input: input, configuration: configuration, quota: .init(remaining: remaining, resetsAt: resetAt ?? now.addingTimeInterval(86_400)), connectivity: connectivity, now: now, snapshotFreshnessLimit: 3_600)
    }
}
