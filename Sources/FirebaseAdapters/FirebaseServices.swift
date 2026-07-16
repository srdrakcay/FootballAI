import CoreDomain
import FirebaseAuth
import FirebaseFunctions
import Foundation

public enum FirebaseEnvironment {
    public static let projectID = "footballai-40789"
    public static let functionsRegion = "europe-west1"
}

public protocol AuthenticationService: Sendable {
    func ensureAnonymousUser() async throws -> String
    func signOut() async throws
    func deleteAccount() async throws
}

public actor FirebaseAuthenticationService: AuthenticationService {
    private var pendingSignIn: Task<String, any Error>?
    private var bootstrappedUIDs: Set<String> = []

    public init() {}
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
            throw Self.domainError(from: error)
        }
    }

    private static func domainError(from error: any Error) -> any Error {
        let value = error as NSError
        guard value.domain == FunctionsErrorDomain else { return error }
        let details = value.userInfo[FunctionsErrorDetailsKey] as? [String: Any]
        let reason = details?["reason"] as? String

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
