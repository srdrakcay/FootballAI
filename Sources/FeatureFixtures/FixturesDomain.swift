import CoreDomain
import Foundation

public protocol FixtureRepository: Sendable {
    func observeUpcoming(filter: FixtureFilter) -> AsyncThrowingStream<[Fixture], any Error>
    func fixture(id: FixtureKey) async throws -> Fixture
    func insights(id: FixtureKey) async throws -> FixtureInsights
}

public protocol ObserveUpcomingFixturesUseCase: Sendable {
    func callAsFunction(filter: FixtureFilter) -> AsyncThrowingStream<[Fixture], any Error>
}

public struct DefaultObserveUpcomingFixturesUseCase: ObserveUpcomingFixturesUseCase {
    private let repository: any FixtureRepository
    public init(repository: any FixtureRepository) { self.repository = repository }
    public func callAsFunction(filter: FixtureFilter) -> AsyncThrowingStream<[Fixture], any Error> { repository.observeUpcoming(filter: filter) }
}

public protocol GetFixtureDetailUseCase: Sendable { func callAsFunction(id: FixtureKey) async throws -> Fixture }
public struct DefaultGetFixtureDetailUseCase: GetFixtureDetailUseCase {
    private let repository: any FixtureRepository
    public init(repository: any FixtureRepository) { self.repository = repository }
    public func callAsFunction(id: FixtureKey) async throws -> Fixture { try await repository.fixture(id: id) }
}

public struct InMemoryFixtureRepository: FixtureRepository {
    private let fixtures: [Fixture]
    public init(fixtures: [Fixture]) { self.fixtures = fixtures }
    public func observeUpcoming(filter: FixtureFilter) -> AsyncThrowingStream<[Fixture], any Error> {
        let values = fixtures.filter { fixture in
            fixture.kickoffAt >= filter.from && fixture.kickoffAt <= filter.through &&
            (filter.competitionIDs.isEmpty || filter.competitionIDs.contains(fixture.competition.id))
        }.sorted { $0.kickoffAt < $1.kickoffAt }
        return AsyncThrowingStream { continuation in continuation.yield(values); continuation.finish() }
    }
    public func fixture(id: FixtureKey) async throws -> Fixture {
        guard let fixture = fixtures.first(where: { $0.key == id }) else { throw DomainError.fixtureNotFound }
        return fixture
    }
    public func insights(id: FixtureKey) async throws -> FixtureInsights {
        guard fixtures.contains(where: { $0.key == id }) else { throw DomainError.fixtureNotFound }
        return FixtureInsights(
            fixtureKey: id,
            dataSnapshotAt: ISO8601DateFormatter().string(from: .now),
            recentForm: TeamFormPair(
                home: TeamRecentForm(matches: [], wins: 3, draws: 1, losses: 1, goalsFor: 9, goalsAgainst: 5, form: ["W", "W", "D", "L", "W"]),
                away: TeamRecentForm(matches: [], wins: 2, draws: 2, losses: 1, goalsFor: 7, goalsAgainst: 6, form: ["D", "W", "L", "W", "D"])
            ),
            headToHead: [],
            standings: TeamStandingPair(
                home: TeamStanding(position: 2, playedGames: 24, form: nil, won: 16, draw: 5, lost: 3, points: 53, goalsFor: 48, goalsAgainst: 21, goalDifference: 27),
                away: TeamStanding(position: 5, playedGames: 24, form: nil, won: 12, draw: 7, lost: 5, points: 43, goalsFor: 39, goalsAgainst: 28, goalDifference: 11)
            ),
            unavailableSections: ["lineups", "weather"]
        )
    }
}
