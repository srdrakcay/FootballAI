import Foundation

public struct CreditWallet: Equatable, Sendable, Codable {
    public let balance: Int
    /// Credits held by an in-flight analysis; they are part of `balance` but cannot be spent.
    public let reserved: Int
    public let analysisCreditCost: Int

    public init(balance: Int, reserved: Int = 0, analysisCreditCost: Int) {
        self.balance = max(0, balance)
        self.reserved = min(max(0, reserved), max(0, balance))
        self.analysisCreditCost = min(max(analysisCreditCost, 1), 100)
    }

    public var available: Int { max(0, balance - reserved) }
    public var canAffordAnalysis: Bool { available >= analysisCreditCost }
    public var analysesAffordable: Int { available / analysisCreditCost }

    public static let defaultValue = CreditWallet(balance: 0, analysisCreditCost: 1)

    private enum CodingKeys: String, CodingKey { case balance, reserved, analysisCreditCost }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            balance: try container.decodeIfPresent(Int.self, forKey: .balance) ?? 0,
            reserved: try container.decodeIfPresent(Int.self, forKey: .reserved) ?? 0,
            analysisCreditCost: try container.decodeIfPresent(Int.self, forKey: .analysisCreditCost) ?? 1
        )
    }
}

public enum CreditLedgerKind: String, Codable, Sendable {
    case welcomeGrant = "welcome_grant", purchase, refund, analysisUnlock = "analysis_unlock", adjustment
}

public struct CreditLedgerEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: CreditLedgerKind
    public let delta: Int
    public let balanceAfter: Int
    public let label: String?
    public let createdAt: Date

    public init(id: String, kind: CreditLedgerKind, delta: Int, balanceAfter: Int, label: String?, createdAt: Date) {
        self.id = id; self.kind = kind; self.delta = delta
        self.balanceAfter = balanceAfter; self.label = label; self.createdAt = createdAt
    }
}

public protocol CreditWalletRepository: Sendable {
    func wallet() async throws -> CreditWallet
    /// Live balance. Emits the current value first, then every server change (purchases, refunds, spends).
    func observe() -> AsyncStream<CreditWallet>
    func ledger(limit: Int) async throws -> [CreditLedgerEntry]
}

public actor InMemoryCreditWalletRepository: CreditWalletRepository {
    private var value: CreditWallet
    private var entries: [CreditLedgerEntry]
    private var continuations: [UUID: AsyncStream<CreditWallet>.Continuation] = [:]

    public init(value: CreditWallet = .defaultValue, ledger: [CreditLedgerEntry] = []) {
        self.value = value
        self.entries = ledger
    }

    public func wallet() -> CreditWallet { value }

    public func ledger(limit: Int) -> [CreditLedgerEntry] { Array(entries.prefix(limit)) }

    public nonisolated func observe() -> AsyncStream<CreditWallet> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.register(id, continuation) }
            continuation.onTermination = { _ in Task { await self.unregister(id) } }
        }
    }

    public func set(_ wallet: CreditWallet) {
        value = wallet
        continuations.values.forEach { $0.yield(wallet) }
    }

    private func register(_ id: UUID, _ continuation: AsyncStream<CreditWallet>.Continuation) {
        continuations[id] = continuation
        continuation.yield(value)
    }

    private func unregister(_ id: UUID) { continuations[id] = nil }
}
