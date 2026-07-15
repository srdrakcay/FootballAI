import CoreDomain
import FeatureFixtures
import XCTest

final class FixtureUseCaseTests: XCTestCase {
    func testObserveFiltersDateRange() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let competition = Competition(id: .init(rawValue: "PL"), name: "Premier League")
        let team = Team(id: .init(rawValue: "A"), name: "A")
        let inside = Fixture(key: .init(rawValue: "inside"), version: 1, competition: competition, homeTeam: team, awayTeam: team, kickoffAt: now.addingTimeInterval(100), status: .timed, latestSnapshotID: nil)
        let outside = Fixture(key: .init(rawValue: "outside"), version: 1, competition: competition, homeTeam: team, awayTeam: team, kickoffAt: now.addingTimeInterval(10_000), status: .timed, latestSnapshotID: nil)
        let useCase = DefaultObserveUpcomingFixturesUseCase(repository: InMemoryFixtureRepository(fixtures: [outside, inside]))
        var received: [Fixture] = []
        for try await fixtures in useCase(filter: FixtureFilter(from: now, through: now.addingTimeInterval(500))) { received = fixtures }
        XCTAssertEqual(received.map(\.key), [inside.key])
    }
}
