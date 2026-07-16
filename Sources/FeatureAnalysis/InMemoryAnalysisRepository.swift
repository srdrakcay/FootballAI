import CoreDomain
import Foundation

public actor InMemoryAnalysisRepository: AnalysisRepository {
    private var analyses: [AnalysisID: Analysis]
    public init(analyses: [Analysis] = []) { self.analyses = Dictionary(uniqueKeysWithValues: analyses.map { ($0.id, $0) }) }
    public func request(_ command: RequestAnalysisCommand) async throws -> AnalysisRequest {
        guard let analysis = analyses.values.first(where: { $0.fixtureKey == command.fixtureKey }) else {
            throw DomainError.generationFailedPermanent(referenceID: "mock-no-analysis")
        }
        return AnalysisRequest(id: .init(rawValue: command.clientRequestID.uuidString), analysisID: analysis.id, state: .ready)
    }
    public nonisolated func observe(requestID: AnalysisRequestID) -> AsyncThrowingStream<AnalysisState, any Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.queued); continuation.yield(.generating); continuation.yield(.validating); continuation.yield(.ready); continuation.finish()
        }
    }
    public func analysis(id: AnalysisID, locale: SupportedLocale) async throws -> Analysis {
        guard let analysis = analyses[id] else { throw DomainError.generationFailedPermanent(referenceID: "mock-not-found") }
        return analysis
    }
    public func existing(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> Analysis? {
        analyses.values.first(where: { $0.fixtureKey == fixtureKey })
    }
}
