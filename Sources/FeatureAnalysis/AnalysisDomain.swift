import CoreDomain
import Foundation

public protocol AnalysisRepository: Sendable {
    func request(_ command: RequestAnalysisCommand) async throws -> AnalysisRequest
    func observe(requestID: AnalysisRequestID) -> AsyncThrowingStream<AnalysisState, any Error>
    func analysis(id: AnalysisID, locale: SupportedLocale) async throws -> Analysis
}
public protocol RequestAnalysisUseCase: Sendable { func callAsFunction(_ command: RequestAnalysisCommand) async throws -> AnalysisRequest }
public struct DefaultRequestAnalysisUseCase: RequestAnalysisUseCase {
    private let repository: any AnalysisRepository
    public init(repository: any AnalysisRepository) { self.repository = repository }
    public func callAsFunction(_ command: RequestAnalysisCommand) async throws -> AnalysisRequest { try await repository.request(command) }
}
public protocol ObserveAnalysisUseCase: Sendable { func callAsFunction(requestID: AnalysisRequestID) -> AsyncThrowingStream<AnalysisState, any Error> }
public struct DefaultObserveAnalysisUseCase: ObserveAnalysisUseCase {
    private let repository: any AnalysisRepository
    public init(repository: any AnalysisRepository) { self.repository = repository }
    public func callAsFunction(requestID: AnalysisRequestID) -> AsyncThrowingStream<AnalysisState, any Error> { repository.observe(requestID: requestID) }
}
public protocol GetLocalizedAnalysisUseCase: Sendable { func callAsFunction(id: AnalysisID, locale: SupportedLocale) async throws -> Analysis }
public struct DefaultGetLocalizedAnalysisUseCase: GetLocalizedAnalysisUseCase {
    private let repository: any AnalysisRepository
    public init(repository: any AnalysisRepository) { self.repository = repository }
    public func callAsFunction(id: AnalysisID, locale: SupportedLocale) async throws -> Analysis { try await repository.analysis(id: id, locale: locale) }
}

public protocol GetAnalysisEligibilityUseCase: Sendable {
    func callAsFunction(fixture: Fixture, input: AnalysisInputSummary?, configuration: AppConfiguration, quota: QuotaStatus, connectivity: ConnectivityStatus, now: Date) -> AnalysisEligibility
}

public struct DefaultGetAnalysisEligibilityUseCase: GetAnalysisEligibilityUseCase {
    private let policy: AnalysisEligibilityPolicy
    private let snapshotFreshnessLimit: TimeInterval
    public init(policy: AnalysisEligibilityPolicy = .init(), snapshotFreshnessLimit: TimeInterval = 3_600) {
        self.policy = policy; self.snapshotFreshnessLimit = snapshotFreshnessLimit
    }
    public func callAsFunction(fixture: Fixture, input: AnalysisInputSummary?, configuration: AppConfiguration, quota: QuotaStatus, connectivity: ConnectivityStatus, now: Date) -> AnalysisEligibility {
        policy.evaluate(fixture: fixture, input: input, configuration: configuration, quota: quota, connectivity: connectivity, now: now, snapshotFreshnessLimit: snapshotFreshnessLimit)
    }
}
