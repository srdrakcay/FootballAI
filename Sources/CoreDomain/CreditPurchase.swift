import Foundation

public struct CreditPackage: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let localizedPrice: String

    public init(id: String, title: String, localizedPrice: String) {
        self.id = id
        self.title = title
        self.localizedPrice = localizedPrice
    }
}

public enum CreditPurchaseResult: Equatable, Sendable {
    case purchased
    case cancelled
}

public protocol CreditPurchaseService: Sendable {
    func configure(publicAPIKey: String, appUserID: String) async throws
    func packages() async throws -> [CreditPackage]
    func purchase(packageID: String) async throws -> CreditPurchaseResult
    func resetUser() async
}

public actor InMemoryCreditPurchaseService: CreditPurchaseService {
    public init() {}
    public func configure(publicAPIKey: String, appUserID: String) {}
    public func packages() -> [CreditPackage] { [] }
    public func purchase(packageID: String) throws -> CreditPurchaseResult { .cancelled }
    public func resetUser() {}
}
