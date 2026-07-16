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

    @MainActor
    func testInsufficientCreditsHasDedicatedPresentationState() async {
        let viewModel = AnalysisViewModel(
            fixtureKey: .init(rawValue: "fixture"),
            locale: .en,
            findExistingAnalysis: NoExistingAnalysis(),
            requestAnalysis: InsufficientCreditRequest(),
            observeAnalysis: EmptyObservation(),
            getAnalysis: UnavailableAnalysis()
        )

        viewModel.generate()
        for _ in 0..<20 where viewModel.state != .insufficientCredits {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.state, .insufficientCredits)
    }

    @MainActor
    func testExistingAnalysisIsLoadedWithoutGeneration() async throws {
        let analysis = try sampleAnalysis()
        let request = CountingRequest()
        let viewModel = AnalysisViewModel(
            fixtureKey: analysis.fixtureKey,
            locale: .en,
            findExistingAnalysis: ExistingAnalysis(value: analysis),
            requestAnalysis: request,
            observeAnalysis: EmptyObservation(),
            getAnalysis: UnavailableAnalysis()
        )

        viewModel.loadExisting()
        for _ in 0..<20 {
            if case .ready = viewModel.state { break }
            await Task.yield()
        }

        XCTAssertEqual(viewModel.state, .ready(analysis))
        let count = await request.count()
        XCTAssertEqual(count, 0)
    }
}

private struct InsufficientCreditRequest: RequestAnalysisUseCase {
    func callAsFunction(_ command: RequestAnalysisCommand) async throws -> AnalysisRequest {
        throw DomainError.insufficientCredits(balance: 0, required: 1)
    }
}

private struct EmptyObservation: ObserveAnalysisUseCase {
    func callAsFunction(requestID: AnalysisRequestID) -> AsyncThrowingStream<AnalysisState, any Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private struct NoExistingAnalysis: FindExistingAnalysisUseCase {
    func callAsFunction(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> Analysis? { nil }
}

private struct ExistingAnalysis: FindExistingAnalysisUseCase {
    let value: Analysis
    func callAsFunction(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> Analysis? { value }
}

private actor CountingRequest: RequestAnalysisUseCase {
    private var value = 0
    func callAsFunction(_ command: RequestAnalysisCommand) async throws -> AnalysisRequest {
        value += 1
        throw DomainError.generationFailedPermanent(referenceID: "unexpected-request")
    }
    func count() -> Int { value }
}

private struct UnavailableAnalysis: GetLocalizedAnalysisUseCase {
    func callAsFunction(id: AnalysisID, locale: SupportedLocale) async throws -> Analysis {
        throw DomainError.generationFailedPermanent(referenceID: "unexpected-analysis-read")
    }
}

private func sampleAnalysis() throws -> Analysis {
    let match = try MatchResultProbabilities(home: 45, draw: 30, away: 25)
    let goals = try BinaryProbabilities(yes: 55, no: 45)
    let btts = try BinaryProbabilities(yes: 52, no: 48)
    let score = try ScorelineProbability(home: 1, away: 0, percentage: 12)
    let markets = try ProbabilityMarkets(
        matchResult: match,
        goalsOver25: goals,
        bothTeamsScore: btts,
        likelyScores: [score],
        otherScoresPercentage: 88
    )
    let confidence = try Confidence(level: .medium, scorePercentage: 62)
    return Analysis(
        id: .init(rawValue: "existing-analysis"),
        fixtureKey: .init(rawValue: "fixture"),
        fixtureVersion: 1,
        snapshotID: .init(rawValue: "snapshot"),
        snapshotVersion: 1,
        schemaVersion: "2.0",
        promptVersion: "test",
        modelVersion: "test",
        generatedAt: .now.addingTimeInterval(-7200),
        validUntil: .now.addingTimeInterval(-3600),
        language: .en,
        markets: markets,
        confidence: confidence,
        rationale: [],
        dataAvailability: [:],
        limitations: [],
        moderationStatus: .passed
    )
}
