import CoreDomain
import XCTest

final class ProbabilityTests: XCTestCase {
    func testMatchResultMustTotalOneHundred() throws {
        XCTAssertNoThrow(try MatchResultProbabilities(home: 40, draw: 30, away: 30))
        XCTAssertThrowsError(try MatchResultProbabilities(home: 40, draw: 30, away: 29))
    }

    func testScorelineDistributionRejectsDuplicatesAndInvalidRemainder() throws {
        let match = try MatchResultProbabilities(home: 40, draw: 30, away: 30)
        let binary = try BinaryProbabilities(yes: 50, no: 50)
        let score = try ScorelineProbability(home: 1, away: 1, percentage: 10)
        XCTAssertThrowsError(try ProbabilityMarkets(matchResult: match, goalsOver25: binary, bothTeamsScore: binary, likelyScores: [score, score], otherScoresPercentage: 80))
        XCTAssertThrowsError(try ProbabilityMarkets(matchResult: match, goalsOver25: binary, bothTeamsScore: binary, likelyScores: [score], otherScoresPercentage: 89))
    }

    func testPlanLimitsAreClamped() {
        let limits = PlanLimits(freeMonthlyUniqueViews: 100, freeHistoryDays: 0, premiumHistoryDays: 900)
        XCTAssertEqual(limits.freeMonthlyUniqueViews, 20)
        XCTAssertEqual(limits.freeHistoryDays, 1)
        XCTAssertEqual(limits.premiumHistoryDays, 730)
    }

    func testLocaleResolutionUsesBaseThenEnglish() {
        XCTAssertEqual(SupportedLocale.resolve(identifier: "tr-TR"), .tr)
        XCTAssertEqual(SupportedLocale.resolve(identifier: "de-DE"), .en)
    }
}
