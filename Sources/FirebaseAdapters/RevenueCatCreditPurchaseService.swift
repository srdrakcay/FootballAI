@preconcurrency import RevenueCat
import CoreDomain
import Foundation

public actor RevenueCatCreditPurchaseService: CreditPurchaseService {
    private var configuredUserID: String?

    public init() {}

    public func configure(publicAPIKey: String, appUserID: String) async throws {
        guard !publicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RevenueCatConfigurationError.missingPublicAPIKey
        }
        if !Purchases.isConfigured {
#if DEBUG
            Purchases.logLevel = .debug
#endif
            Purchases.configure(withAPIKey: publicAPIKey, appUserID: appUserID)
        } else if configuredUserID != appUserID {
            _ = try await Purchases.shared.logIn(appUserID)
        }
        configuredUserID = appUserID
    }

    public func packages() async throws -> [CreditPackage] {
        guard Purchases.isConfigured else { throw RevenueCatConfigurationError.notConfigured }
        let offerings = try await Purchases.shared.offerings()
        return (offerings.current?.availablePackages ?? []).map { package in
            let product = package.storeProduct
            let credits = CreditPackage.credits(fromIdentifier: product.productIdentifier)
                ?? CreditPackage.credits(fromIdentifier: package.identifier)
            var perCredit: String?
            if let credits, credits > 0, let formatter = product.priceFormatter {
                perCredit = formatter.string(from: NSDecimalNumber(decimal: product.price / Decimal(credits)))
            }
            return CreditPackage(
                id: package.identifier,
                title: product.localizedTitle,
                localizedPrice: product.localizedPriceString,
                credits: credits,
                price: product.price,
                localizedPricePerCredit: perCredit
            )
        }
        .sorted { ($0.credits ?? 0) < ($1.credits ?? 0) }
    }

    public func purchase(packageID: String) async throws -> CreditPurchaseResult {
        guard Purchases.isConfigured else { throw RevenueCatConfigurationError.notConfigured }
        let offerings = try await Purchases.shared.offerings()
        guard let package = offerings.current?.availablePackages.first(where: { $0.identifier == packageID }) else {
            throw RevenueCatConfigurationError.packageUnavailable
        }
        let result = try await Purchases.shared.purchase(package: package)
        return result.userCancelled ? .cancelled : .purchased
    }

    public func resetUser() async {
        guard Purchases.isConfigured else { return }
        _ = try? await Purchases.shared.logOut()
        configuredUserID = nil
    }
}

public enum RevenueCatConfigurationError: Error, Sendable {
    case missingPublicAPIKey
    case notConfigured
    case packageUnavailable
}
