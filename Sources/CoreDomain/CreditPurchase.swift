import Foundation

public struct CreditPackage: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let localizedPrice: String
    /// Credits granted by the pack, parsed from the store product identifier (`…_credits_10`).
    public let credits: Int?
    public let price: Decimal?
    /// Localized price of one credit, formatted with the store's own currency formatter.
    public let localizedPricePerCredit: String?

    public init(id: String, title: String, localizedPrice: String, credits: Int? = nil, price: Decimal? = nil, localizedPricePerCredit: String? = nil) {
        self.id = id
        self.title = title
        self.localizedPrice = localizedPrice
        self.credits = credits ?? Self.credits(fromIdentifier: id)
        self.price = price
        self.localizedPricePerCredit = localizedPricePerCredit
    }

    public static func credits(fromIdentifier identifier: String) -> Int? {
        identifier.split(whereSeparator: { !$0.isNumber }).last.flatMap { Int($0) }
    }

    public var pricePerCredit: Decimal? {
        guard let price, let credits, credits > 0 else { return nil }
        return price / Decimal(credits)
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
    private let values: [CreditPackage]
    public init(packages: [CreditPackage] = []) { values = packages }
    public func configure(publicAPIKey: String, appUserID: String) {}
    public func packages() -> [CreditPackage] { values }
    public func purchase(packageID: String) throws -> CreditPurchaseResult { .cancelled }
    public func resetUser() {}
}
