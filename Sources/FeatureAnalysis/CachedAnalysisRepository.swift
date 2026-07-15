import CoreDomain
import CorePersistence
import Foundation

public actor CachedAnalysisRepository: AnalysisRepository {
    private let remote: any AnalysisRepository
    private let cache: any AnalysisCaching
    private let connectivity: any ConnectivityProviding
    private let now: @Sendable () -> Date

    public init(remote: any AnalysisRepository, cache: any AnalysisCaching, connectivity: any ConnectivityProviding, now: @escaping @Sendable () -> Date = { .now }) {
        self.remote = remote; self.cache = cache; self.connectivity = connectivity; self.now = now
    }

    public func request(_ command: RequestAnalysisCommand) async throws -> AnalysisRequest {
        guard await connectivity.current() == .online else { throw DomainError.networkOffline }
        return try await remote.request(command)
    }

    public nonisolated func observe(requestID: AnalysisRequestID) -> AsyncThrowingStream<AnalysisState, any Error> {
        remote.observe(requestID: requestID)
    }

    public func analysis(id: AnalysisID, locale: SupportedLocale) async throws -> Analysis {
        if let cached = await cache.value(for: id, locale: locale, now: now()) { return cached }
        guard await connectivity.current() == .online else { throw DomainError.networkOffline }
        let value = try await remote.analysis(id: id, locale: locale)
        try await cache.store(value)
        return value
    }
}
