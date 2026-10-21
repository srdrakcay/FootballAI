import CoreDomain
import FirebaseAuth
import FirebaseFunctions
import Foundation
import OSLog

public enum FirebaseEnvironment {
    public static let projectID = "footballai-40789"
    public static let functionsRegion = "europe-west1"
}

public protocol AuthenticationService: Sendable {
    func ensureAnonymousUser() async throws -> String
    /// Signs in if needed and returns the bootstrap payload (wallet, AI profile) in one call.
    func session(locale: SupportedLocale) async throws -> SessionInfo
    func signOut() async throws
    func deleteAccount() async throws
}

public actor FirebaseAuthenticationService: AuthenticationService {
    private var pendingSignIn: Task<String, any Error>?
    private var bootstrappedUIDs: Set<String> = []
    private var sessions: [String: SessionInfo] = [:]

    public init() {}

    public func session(locale: SupportedLocale) async throws -> SessionInfo {
        let uid = try await ensureAnonymousUser()
        if let cached = sessions[uid] { return cached }
        let result = try await Functions.functions(region: FirebaseEnvironment.functionsRegion)
            .httpsCallable("bootstrapUser")
            .call(["locale": locale.rawValue])
        let info = Self.sessionInfo(uid: uid, data: result.data)
        sessions[uid] = info
        bootstrappedUIDs.insert(uid)
        return info
    }

    private static func sessionInfo(uid: String, data: Any) -> SessionInfo {
        let payload = data as? [String: Any] ?? [:]
        let walletData = payload["wallet"] as? [String: Any]
        let wallet = CreditWallet(
            balance: integer(walletData?["balance"] ?? payload["balance"]) ?? 0,
            reserved: integer(walletData?["reserved"]) ?? 0,
            analysisCreditCost: integer(walletData?["analysisCreditCost"] ?? payload["analysisCreditCost"]) ?? 1
        )
        var profile: AIProfile?
        if let raw = payload["aiProfile"], JSONSerialization.isValidJSONObject(raw),
           let encoded = try? JSONSerialization.data(withJSONObject: raw) {
            profile = try? JSONDecoder().decode(AIProfile.self, from: encoded)
        }
        return SessionInfo(uid: uid, wallet: wallet, aiProfile: profile)
    }
    public func ensureAnonymousUser() async throws -> String {
        let uid: String
        if let current = Auth.auth().currentUser { uid = current.uid }
        else if let pendingSignIn { uid = try await pendingSignIn.value }
        else {
            let task = Task { try await Auth.auth().signInAnonymously().user.uid }
            pendingSignIn = task
            do {
                uid = try await task.value
                pendingSignIn = nil
            } catch {
                pendingSignIn = nil
                throw error
            }
        }

        guard !bootstrappedUIDs.contains(uid) else { return uid }
        _ = try await Auth.auth().currentUser?.getIDToken()

        Auth.auth().useAppLanguage()
        let locale = SupportedLocale.resolve(identifier: Locale.autoupdatingCurrent.identifier).rawValue
        do {
            _ = try await Functions.functions(region: FirebaseEnvironment.functionsRegion)
                .httpsCallable("bootstrapUser")
                .call(["locale": locale])
            bootstrappedUIDs.insert(uid)
        } catch {
            // Authentication remains valid if profile bootstrap is temporarily unavailable.
            // Fixture reads can continue and the next ensure call retries profile creation.
        }
        return uid
    }

    public func signOut() throws {
        sessions.removeAll()
        pendingSignIn?.cancel()
        pendingSignIn = nil
        bootstrappedUIDs.removeAll()
        try Auth.auth().signOut()
    }

    public func deleteAccount() async throws {
        let uid = try await ensureAnonymousUser()
        _ = try await Auth.auth().currentUser?.getIDToken(forcingRefresh: true)
        _ = try await Functions.functions(region: FirebaseEnvironment.functionsRegion)
            .httpsCallable("deleteAccount")
            .call(["confirmation": "DELETE"])
        bootstrappedUIDs.remove(uid)
        sessions[uid] = nil
        pendingSignIn?.cancel()
        pendingSignIn = nil
        try? Auth.auth().signOut()
    }
}

public actor FirebaseCallableTransport: CallableTransport {
    private let region: String
    public init(region: String = FirebaseEnvironment.functionsRegion) { self.region = region }

    public func call<Request: Encodable & Sendable, Response: Decodable & Sendable>(_ name: String, request: Request) async throws -> Response {
        do {
            let encoded = try JSONEncoder().encode(request)
            let payload = try JSONSerialization.jsonObject(with: encoded)
            let result = try await Functions.functions(region: region).httpsCallable(name).call(payload)
            guard JSONSerialization.isValidJSONObject(result.data) else { throw URLError(.cannotParseResponse) }
            let responseData = try JSONSerialization.data(withJSONObject: result.data)
            return try JSONDecoder().decode(Response.self, from: responseData)
        } catch {
            Self.log(callable: name, error: error)
            throw Self.domainError(from: error)
        }
    }

    private static let logger = Logger(subsystem: "com.footballai.predictions", category: "callable")

    /// Console.app / Xcode console: filter by category "callable". The server code (HttpsError message) is the
    /// reason; traceId-based server logs are in Cloud Logging under the same function name.
    private static func log(callable name: String, error: any Error) {
        let value = error as NSError
        let details = (value.userInfo[FunctionsErrorDetailsKey] as? [String: Any]).map { String(describing: $0) } ?? "-"
        logger.error("\(name, privacy: .public) failed domain=\(value.domain, privacy: .public) code=\(value.code, privacy: .public) message=\(value.localizedDescription, privacy: .public) details=\(details, privacy: .public)")
    }

    private static func domainError(from error: any Error) -> any Error {
        let value = error as NSError
        guard value.domain == FunctionsErrorDomain else { return error }
        let details = value.userInfo[FunctionsErrorDetailsKey] as? [String: Any]
        let reason = details?["reason"] as? String
        let message = value.localizedDescription

        // Server-reported analysis outcomes must not be shown as "you are offline".
        if value.code == FunctionsErrorCode.unavailable.rawValue, message == "ANALYSIS_GENERATION_FAILED" {
            return DomainError.generationFailedRetryable(retryAfter: nil)
        }
        if value.code == FunctionsErrorCode.internal.rawValue, message == "ANALYSIS_VALIDATION_FAILED" {
            return DomainError.generationFailedPermanent(referenceID: message)
        }
        if value.code == FunctionsErrorCode.resourceExhausted.rawValue, message == "MODEL_RATE_LIMITED" {
            return DomainError.rateLimited(retryAfter: nil)
        }
        if value.code == FunctionsErrorCode.failedPrecondition.rawValue {
            if message == "FIXTURE_INELIGIBLE" || message == "ANALYSIS_UNAVAILABLE_FOR_COMPETITION" { return DomainError.fixtureIneligible(reason: message) }
            if message == "DATA_INSUFFICIENT" { return DomainError.dataInsufficient(missingCodes: []) }
        }

        if value.code == FunctionsErrorCode.resourceExhausted.rawValue, reason == "INSUFFICIENT_CREDITS" {
            return DomainError.insufficientCredits(
                balance: max(0, numericInteger(details?["balance"]) ?? 0),
                required: max(1, numericInteger(details?["requiredCredits"]) ?? 1)
            )
        }
        if value.code == FunctionsErrorCode.failedPrecondition.rawValue,
           value.localizedDescription == "CONFIG_UNAVAILABLE" {
            return DomainError.configUnavailable
        }
        if value.code == FunctionsErrorCode.unauthenticated.rawValue { return DomainError.authRequired }
        if value.code == FunctionsErrorCode.notFound.rawValue { return DomainError.fixtureNotFound }
        if value.code == FunctionsErrorCode.unavailable.rawValue { return DomainError.networkOffline }
        return error
    }

    private static func numericInteger(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue ?? value as? Int
    }
}
