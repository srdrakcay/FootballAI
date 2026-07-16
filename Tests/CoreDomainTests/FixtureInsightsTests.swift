import CoreDomain
import Foundation
import XCTest

final class FixtureInsightsTests: XCTestCase {
    func testCallablePayloadDecodesStringFixtureKey() throws {
        let data = Data("""
        {
          "fixtureKey": "football-data:123",
          "dataSnapshotAt": "2026-07-16T12:00:00.000Z",
          "recentForm": null,
          "headToHead": [],
          "standings": null,
          "unavailableSections": ["lineups", "weather"]
        }
        """.utf8)

        let insights = try JSONDecoder().decode(FixtureInsights.self, from: data)

        XCTAssertEqual(insights.fixtureKey.rawValue, "football-data:123")
        XCTAssertEqual(insights.unavailableSections, ["lineups", "weather"])
    }
}
