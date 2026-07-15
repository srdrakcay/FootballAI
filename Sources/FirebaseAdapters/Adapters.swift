import CoreDomain
import FeatureAnalysis
import FeatureFixtures
import Foundation

public protocol CallableTransport: Sendable {
    func call<Request: Encodable & Sendable, Response: Decodable & Sendable>(_ name: String, request: Request) async throws -> Response
}

public protocol RemoteConfigurationService: Sendable {
    func bootstrap() async -> AppConfiguration
    func fetchAndActivate() async throws -> AppConfiguration
}

public actor InMemoryRemoteConfigurationService: RemoteConfigurationService {
    private var configuration: AppConfiguration
    public init(configuration: AppConfiguration = .safeDefaults) { self.configuration = configuration }
    public func bootstrap() -> AppConfiguration { configuration }
    public func fetchAndActivate() async throws -> AppConfiguration { configuration }
}

public struct UnconfiguredCallableTransport: CallableTransport {
    public init() {}
    public func call<Request: Encodable & Sendable, Response: Decodable & Sendable>(_ name: String, request: Request) async throws -> Response {
        throw DomainError.configUnavailable
    }
}

/// Marker namespace for future SDK-backed adapters. Firebase types must remain inside this module.
public enum FirebaseAdapterBoundary: Sendable {}
