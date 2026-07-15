import Foundation

public struct CreditWallet: Equatable, Sendable {
    public let balance: Int
    public let analysisCreditCost: Int

    public init(balance: Int, analysisCreditCost: Int) {
        self.balance = max(0, balance)
        self.analysisCreditCost = min(max(analysisCreditCost, 1), 100)
    }

    public static let defaultValue = CreditWallet(balance: 1, analysisCreditCost: 1)
}

public protocol CreditWalletRepository: Sendable {
    func wallet() async throws -> CreditWallet
}

public actor InMemoryCreditWalletRepository: CreditWalletRepository {
    private let value: CreditWallet
    public init(value: CreditWallet = .defaultValue) { self.value = value }
    public func wallet() -> CreditWallet { value }
}
