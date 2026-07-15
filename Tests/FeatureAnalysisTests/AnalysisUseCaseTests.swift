import CoreDomain
import FeatureAnalysis
import XCTest

final class AnalysisUseCaseTests: XCTestCase {
    func testMissingMockAnalysisFailsClosed() async {
        let repository = InMemoryAnalysisRepository()
        let useCase = DefaultRequestAnalysisUseCase(repository: repository)
        let command = RequestAnalysisCommand(fixtureKey: .init(rawValue: "missing"), requestedLocale: .en, clientRequestID: UUID(), acceptedDisclaimerVersion: "legal_v1")
        do { _ = try await useCase(command); XCTFail("Expected failure") } catch { XCTAssertEqual(error as? DomainError, .generationFailedPermanent(referenceID: "mock-no-analysis")) }
    }

    func testMockStateSequenceEndsReady() async throws {
        let useCase = DefaultObserveAnalysisUseCase(repository: InMemoryAnalysisRepository())
        var states: [AnalysisState] = []
        for try await state in useCase(requestID: .init(rawValue: "request")) { states.append(state) }
        XCTAssertEqual(states, [.queued, .generating, .validating, .ready])
    }
}
