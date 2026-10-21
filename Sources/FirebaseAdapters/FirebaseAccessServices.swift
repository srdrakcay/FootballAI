import CoreDomain
import FirebaseFirestore
import Foundation

public actor FirebaseAnalysisAccessService: AnalysisAccessService {
    private let authentication: any AuthenticationService
    private let callable: any CallableTransport

    public init(authentication: any AuthenticationService, callable: any CallableTransport) {
        self.authentication = authentication
        self.callable = callable
    }

    public func open(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> AnalysisAccess {
        _ = try await authentication.ensureAnonymousUser()
        let response: AccessResponseDTO = try await callable.call("getAnalysis", request: OpenRequestDTO(fixtureKey: fixtureKey.rawValue, locale: locale.rawValue))
        if let unlocked = response.unlocked { return .unlocked(unlocked) }
        return .locked(response.wallet ?? .defaultValue)
    }

    public func unlock(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> UnlockedAnalysis {
        _ = try await authentication.ensureAnonymousUser()
        let response: AccessResponseDTO = try await callable.call("requestAnalysis", request: UnlockRequestDTO(
            fixtureKey: fixtureKey.rawValue,
            locale: locale.rawValue,
            // One logical attempt per fixture: retries after a dropped connection reuse the same id.
            clientRequestId: String(fixtureKey.rawValue.unicodeScalars.reduce(into: UInt64(1469598103934665603)) { hash, scalar in
                hash = (hash ^ UInt64(scalar.value)) &* 1099511628211
            }),
            acceptedDisclaimerVersion: "legal_v1"
        ))
        guard let unlocked = response.unlocked else { throw DomainError.unknown(referenceID: "analysis-payload") }
        return unlocked
    }
}

public actor FirebaseAIProfileRepository: AIProfileRepository {
    private let authentication: any AuthenticationService
    private let callable: any CallableTransport

    public init(authentication: any AuthenticationService, callable: any CallableTransport) {
        self.authentication = authentication
        self.callable = callable
    }

    public func load() async throws -> AIProfile? {
        let uid = try await authentication.ensureAnonymousUser()
        let document = try await Firestore.firestore().collection("users").document(uid)
            .collection("private").document("aiProfile").getDocument()
        guard var data = document.data() else { return nil }
        data = data.filter { ["favoriteTeam", "competitionIds", "style", "focusMarkets"].contains($0.key) }
        guard JSONSerialization.isValidJSONObject(data) else { return nil }
        return try? JSONDecoder().decode(AIProfile.self, from: JSONSerialization.data(withJSONObject: data))
    }

    public func save(_ profile: AIProfile, locale: SupportedLocale) async throws {
        _ = try await authentication.ensureAnonymousUser()
        let _: ProfileResponseDTO = try await callable.call("updateAIProfile", request: ProfileRequestDTO(profile: profile, locale: locale.rawValue))
    }
}

private struct OpenRequestDTO: Encodable, Sendable { let fixtureKey: String; let locale: String }
private struct UnlockRequestDTO: Encodable, Sendable {
    let fixtureKey: String; let locale: String; let clientRequestId: String; let acceptedDisclaimerVersion: String
}
private struct ProfileRequestDTO: Encodable, Sendable { let profile: AIProfile; let locale: String }
private struct ProfileResponseDTO: Decodable, Sendable { let profile: AIProfile? }

private struct AccessResponseDTO: Decodable, Sendable {
    let state: String
    let analysis: MatchAnalysis?
    let personal: PersonalAnalysis?
    let wallet: CreditWallet?

    var unlocked: UnlockedAnalysis? {
        guard state == "ready", let analysis, let personal else { return nil }
        return UnlockedAnalysis(analysis: analysis, personal: personal, wallet: wallet ?? .defaultValue)
    }
}
