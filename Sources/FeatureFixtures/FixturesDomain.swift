import CoreDomain
import Foundation

public protocol FixtureRepository: Sendable {
    func observeUpcoming(filter: FixtureFilter) -> AsyncThrowingStream<[Fixture], any Error>
    func fixture(id: FixtureKey) async throws -> Fixture
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
}
