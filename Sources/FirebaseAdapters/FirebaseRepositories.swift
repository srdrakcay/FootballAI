import CoreDomain
import FeatureAnalysis
import FeatureFixtures
import FirebaseFirestore
import Foundation

public actor FirebaseCreditWalletRepository: CreditWalletRepository {
    private let authentication: any AuthenticationService
    private let configurationService: any RemoteConfigurationService

    public init(authentication: any AuthenticationService, configurationService: any RemoteConfigurationService) {
        self.authentication = authentication
        self.configurationService = configurationService
    }

    public func wallet() async throws -> CreditWallet {
        let uid = try await authentication.ensureAnonymousUser()
        async let walletDocument = Firestore.firestore().collection("users").document(uid).collection("private").document("wallet").getDocument()
        async let configuration = configurationService.fetchAndActivate()
        let (document, config) = try await (walletDocument, configuration)
        let balance = integer(document.data()?["balance"]) ?? 0
        return CreditWallet(balance: balance, analysisCreditCost: config.analysisCreditCost)
    }
}

public actor FirebaseFixtureRepository: FixtureRepository {
    private let authentication: any AuthenticationService
    private let callable: any CallableTransport
    public init(authentication: any AuthenticationService, callable: any CallableTransport) {
        self.authentication = authentication
        self.callable = callable
    }

    public nonisolated func observeUpcoming(filter: FixtureFilter) -> AsyncThrowingStream<[Fixture], any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    _ = try await authentication.ensureAnonymousUser()
                    let syncPayload = FixtureSyncRequestDTO(
                        dateFrom: Self.apiDate(filter.from),
                        dateTo: Self.apiDate(filter.through.addingTimeInterval(86_400))
                    )
                    let _: FixtureSyncResponseDTO = try await callable.call("syncFixtures", request: syncPayload)
                    let snapshot = try await Firestore.firestore().collection("fixtures")
                        .whereField("kickoffAt", isGreaterThanOrEqualTo: Timestamp(date: filter.from))
                        .whereField("kickoffAt", isLessThanOrEqualTo: Timestamp(date: filter.through))
                        .order(by: "kickoffAt")
                        .getDocuments()
                    let fixtures = try snapshot.documents.map(Self.fixture)
                        .filter { filter.competitionIDs.isEmpty || filter.competitionIDs.contains($0.competition.id) }
                    continuation.yield(fixtures)
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private nonisolated static func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    public func fixture(id: FixtureKey) async throws -> Fixture {
        _ = try await authentication.ensureAnonymousUser()
        let document = try await Firestore.firestore().collection("fixtures").document(id.rawValue).getDocument()
        guard document.exists else { throw DomainError.fixtureNotFound }
        return try Self.fixture(document)
    }

    public func insights(id: FixtureKey) async throws -> FixtureInsights {
        _ = try await authentication.ensureAnonymousUser()
        return try await callable.call("getFixtureInsights", request: FixtureInsightsRequestDTO(fixtureKey: id.rawValue))
    }

    private nonisolated static func fixture(_ document: DocumentSnapshot) throws -> Fixture {
        guard let data = document.data(),
              let competitionID = data["competitionId"] as? String,
              let kickoffAt = date(data["kickoffAt"]),
              let statusRaw = data["status"] as? String,
              let status = FixtureStatus(rawValue: statusRaw),
              let home = team(data["homeTeam"] ?? (data["teams"] as? [String: Any])?["home"]),
              let away = team(data["awayTeam"] ?? (data["teams"] as? [String: Any])?["away"])
        else { throw DomainError.unknown(referenceID: "fixture-decode") }

        return Fixture(
            key: .init(rawValue: document.documentID),
            version: integer(data["fixtureVersion"]) ?? 1,
            competition: .init(id: .init(rawValue: competitionID), name: (data["competitionName"] as? String) ?? competitionID),
            homeTeam: home,
            awayTeam: away,
            kickoffAt: kickoffAt,
            status: status,
            latestSnapshotID: (data["latestSnapshotId"] as? String).map(SnapshotID.init(rawValue:))
        )
    }

    private nonisolated static func team(_ value: Any?) -> Team? {
        guard let data = value as? [String: Any], let name = data["name"] as? String else { return nil }
        let id = (data["id"] as? String) ?? integer(data["id"]).map(String.init) ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
        return Team(id: .init(rawValue: id), name: name)
    }
}

public actor FirebaseUserLibraryRepository: UserLibraryRepository {
    private let authentication: any AuthenticationService

    public init(authentication: any AuthenticationService) { self.authentication = authentication }

    public func favoriteFixtureKeys() async throws -> Set<FixtureKey> {
        let uid = try await authentication.ensureAnonymousUser()
        let snapshot = try await Firestore.firestore().collection("users").document(uid).collection("favorites").getDocuments()
        return Set(snapshot.documents.map { FixtureKey(rawValue: $0.documentID) })
    }

    public func favoriteFixtures() async throws -> [Fixture] {
        let uid = try await authentication.ensureAnonymousUser()
        let snapshot = try await Firestore.firestore().collection("users").document(uid).collection("favorites")
            .order(by: "kickoffAt")
            .getDocuments()
        return snapshot.documents.compactMap(Self.favoriteFixture)
    }

    public func setFavorite(_ fixture: Fixture, isFavorite: Bool) async throws {
        let uid = try await authentication.ensureAnonymousUser()
        let reference = Firestore.firestore().collection("users").document(uid).collection("favorites").document(fixture.key.rawValue)
        if isFavorite {
            try await reference.setData([
                "fixtureKey": fixture.key.rawValue,
                "competitionId": fixture.competition.id.rawValue,
                "competitionName": fixture.competition.name,
                "homeTeam": ["id": fixture.homeTeam.id.rawValue, "name": fixture.homeTeam.name],
                "awayTeam": ["id": fixture.awayTeam.id.rawValue, "name": fixture.awayTeam.name],
                "kickoffAt": Timestamp(date: fixture.kickoffAt),
                "status": fixture.status.rawValue,
                "fixtureVersion": fixture.version,
                "createdAt": FieldValue.serverTimestamp(),
            ])
        } else {
            try await reference.delete()
        }
    }

    private nonisolated static func favoriteFixture(_ document: QueryDocumentSnapshot) -> Fixture? {
        let data = document.data()
        guard let fixtureKey = data["fixtureKey"] as? String,
              let competitionID = data["competitionId"] as? String,
              let competitionName = data["competitionName"] as? String,
              let kickoffAt = date(data["kickoffAt"]),
              let home = team(data["homeTeam"]),
              let away = team(data["awayTeam"])
        else { return nil }
        return Fixture(
            key: .init(rawValue: fixtureKey),
            version: integer(data["fixtureVersion"]) ?? 1,
            competition: .init(id: .init(rawValue: competitionID), name: competitionName),
            homeTeam: home,
            awayTeam: away,
            kickoffAt: kickoffAt,
            status: (data["status"] as? String).flatMap(FixtureStatus.init(rawValue:)) ?? .scheduled,
            latestSnapshotID: nil
        )
    }

    private nonisolated static func team(_ value: Any?) -> Team? {
        guard let data = value as? [String: Any], let name = data["name"] as? String else { return nil }
        let id = (data["id"] as? String) ?? integer(data["id"]).map(String.init) ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
        return Team(id: .init(rawValue: id), name: name)
    }

    public func analysisHistory() async throws -> [AnalysisHistoryItem] {
        let uid = try await authentication.ensureAnonymousUser()
        let snapshot = try await Firestore.firestore().collection("users").document(uid).collection("history")
            .order(by: "viewedAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        return snapshot.documents.compactMap(Self.historyItem)
    }

    private nonisolated static func historyItem(_ document: QueryDocumentSnapshot) -> AnalysisHistoryItem? {
        let data = document.data()
        guard let fixtureKey = data["fixtureKey"] as? String,
              let analysisID = data["analysisId"] as? String,
              let competitionName = data["competitionName"] as? String,
              let homeTeamName = data["homeTeamName"] as? String,
              let awayTeamName = data["awayTeamName"] as? String,
              let kickoffAt = date(data["kickoffAt"]),
              let viewedAt = date(data["viewedAt"]),
              let generatedAt = date(data["generatedAt"]),
              let validUntil = date(data["validUntil"])
        else { return nil }
        return AnalysisHistoryItem(
            id: document.documentID,
            fixtureKey: .init(rawValue: fixtureKey),
            analysisID: .init(rawValue: analysisID),
            competitionName: competitionName,
            homeTeamName: homeTeamName,
            awayTeamName: awayTeamName,
            kickoffAt: kickoffAt,
            viewedAt: viewedAt,
            generatedAt: generatedAt,
            validUntil: validUntil,
            homeWinProbability: integer(data["homeWinProbability"])
        )
    }
}

public actor FirebaseAnalysisRepository: AnalysisRepository {
    private let authentication: any AuthenticationService
    private let callable: any CallableTransport

    public init(authentication: any AuthenticationService, callable: any CallableTransport) {
        self.authentication = authentication
        self.callable = callable
    }

    public func request(_ command: RequestAnalysisCommand) async throws -> AnalysisRequest {
        _ = try await authentication.ensureAnonymousUser()
        let payload = RequestDTO(
            fixtureKey: command.fixtureKey.rawValue,
            locale: command.requestedLocale.rawValue,
            clientRequestId: command.clientRequestID.uuidString,
            acceptedDisclaimerVersion: command.acceptedDisclaimerVersion
        )
        let response: RequestResponseDTO = try await callable.call("requestAnalysis", request: payload)
        guard let state = AnalysisState(rawValue: response.state) else { throw DomainError.unknown(referenceID: "analysis-state") }
        return AnalysisRequest(
            id: .init(rawValue: response.requestId),
            analysisID: response.analysisId.map(AnalysisID.init(rawValue:)),
            state: state
        )
    }

    public nonisolated func observe(requestID: AnalysisRequestID) -> AsyncThrowingStream<AnalysisState, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    _ = try await authentication.ensureAnonymousUser()
                    for attempt in 0..<30 {
                        try Task.checkCancellation()
                        let document = try await Firestore.firestore().collection("analysisRequests").document(requestID.rawValue).getDocument()
                        guard let raw = document.data()?["state"] as? String, let state = AnalysisState(rawValue: raw) else {
                            throw DomainError.unknown(referenceID: "request-not-found")
                        }
                        continuation.yield(state)
                        if [.ready, .failedPermanent, .cancelled, .expired].contains(state) { continuation.finish(); return }
                        if attempt < 29 { try await Task.sleep(for: .seconds(1)) }
                    }
                    continuation.finish(throwing: DomainError.generationFailedRetryable(retryAfter: nil))
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func analysis(id: AnalysisID, locale: SupportedLocale) async throws -> Analysis {
        _ = try await authentication.ensureAnonymousUser()
        let reference = Firestore.firestore().collection("analyses").document(id.rawValue)
        async let parentRequest = reference.getDocument()
        async let localeRequest = reference.collection("locales").document(locale.rawValue).getDocument()
        let (parent, localized) = try await (parentRequest, localeRequest)
        return try Self.analysis(id: id, locale: locale, parent: parent.data(), localized: localized.data())
    }

    public func existing(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> Analysis? {
        let uid = try await authentication.ensureAnonymousUser()
        let history = try await Firestore.firestore()
            .collection("users").document(uid).collection("history")
            .whereField("fixtureKey", isEqualTo: fixtureKey.rawValue)
            .limit(to: 1)
            .getDocuments()
        guard let analysisID = history.documents.first?.data()["analysisId"] as? String else { return nil }
        return try await analysis(id: AnalysisID(rawValue: analysisID), locale: locale)
    }

    private nonisolated static func analysis(id: AnalysisID, locale: SupportedLocale, parent: [String: Any]?, localized: [String: Any]?) throws -> Analysis {
        guard let parent,
              let fixtureKey = parent["fixtureKey"] as? String,
              let snapshotID = parent["snapshotId"] as? String,
              let generatedAt = date(parent["generatedAt"]),
              let validUntil = date(parent["validUntil"]),
              let marketsData = (parent["canonicalMarkets"] ?? parent["markets"]) as? [String: Any],
              let matchData = marketsData["matchResult"] as? [String: Any],
              let goalsData = (marketsData["goals25"] ?? marketsData["goalsOver25"]) as? [String: Any],
              let bttsData = marketsData["bothTeamsScore"] as? [String: Any]
        else { throw DomainError.generationFailedPermanent(referenceID: "analysis-decode") }

        let match = try MatchResultProbabilities(
            home: requiredInt(matchData, "homePct", fallback: "home"),
            draw: requiredInt(matchData, "drawPct", fallback: "draw"),
            away: requiredInt(matchData, "awayPct", fallback: "away")
        )
        let goals = try BinaryProbabilities(
            yes: requiredInt(goalsData, "overPct", fallback: "yes"),
            no: requiredInt(goalsData, "underPct", fallback: "no")
        )
        let btts = try BinaryProbabilities(yes: requiredInt(bttsData, "yesPct", fallback: "yes"), no: requiredInt(bttsData, "noPct", fallback: "no"))
        let scores = try ((marketsData["likelyScores"] as? [[String: Any]]) ?? []).map {
            try ScorelineProbability(home: requiredInt($0, "home"), away: requiredInt($0, "away"), percentage: requiredInt($0, "pct", fallback: "percentage"))
        }
        let markets = try ProbabilityMarkets(
            matchResult: match,
            goalsOver25: goals,
            bothTeamsScore: btts,
            likelyScores: scores,
            otherScoresPercentage: requiredInt(marketsData, "otherScoresPct", fallback: "otherScoresPercentage")
        )
        let confidenceData = parent["confidence"] as? [String: Any] ?? [:]
        guard let level = ConfidenceLevel(rawValue: confidenceData["level"] as? String ?? "") else { throw DomainError.generationFailedPermanent(referenceID: "confidence-decode") }
        let confidence = try Confidence(level: level, scorePercentage: requiredInt(confidenceData, "scorePct", fallback: "scorePercentage"))
        let rationale = ((localized?["rationale"] ?? parent["rationale"]) as? [[String: Any]] ?? []).compactMap { item -> Rationale? in
            guard let code = item["code"] as? String, let text = item["text"] as? String else { return nil }
            return Rationale(code: code, text: text, evidenceRefs: item["evidenceRefs"] as? [String] ?? [])
        }
        let availability = (parent["dataAvailability"] as? [String: String] ?? [:]).reduce(into: [String: DataAvailability]()) { result, pair in result[pair.key] = DataAvailability(rawValue: pair.value) }

        return Analysis(
            id: id, fixtureKey: .init(rawValue: fixtureKey), fixtureVersion: integer(parent["fixtureVersion"]) ?? 1,
            snapshotID: .init(rawValue: snapshotID), snapshotVersion: integer(parent["snapshotVersion"]) ?? 1,
            schemaVersion: parent["schemaVersion"] as? String ?? "2.0", promptVersion: parent["promptVersion"] as? String ?? "unknown",
            modelVersion: parent["modelVersion"] as? String ?? "unknown", generatedAt: generatedAt, validUntil: validUntil, language: locale,
            markets: markets, confidence: confidence, rationale: rationale, dataAvailability: availability,
            limitations: parent["limitations"] as? [String] ?? [], moderationStatus: .passed
        )
    }
}

private struct RequestDTO: Encodable, Sendable {
    let fixtureKey: String; let locale: String; let clientRequestId: String; let acceptedDisclaimerVersion: String
}
private struct RequestResponseDTO: Decodable, Sendable {
    let requestId: String; let analysisId: String?; let state: String
}
private struct FixtureSyncRequestDTO: Encodable, Sendable { let dateFrom: String; let dateTo: String }
private struct FixtureSyncResponseDTO: Decodable, Sendable { let count: Int; let cached: Bool }
private struct FixtureInsightsRequestDTO: Encodable, Sendable { let fixtureKey: String }

private func date(_ value: Any?) -> Date? {
    if let timestamp = value as? Timestamp { return timestamp.dateValue() }
    if let date = value as? Date { return date }
    if let string = value as? String { return ISO8601DateFormatter().date(from: string) }
    return nil
}
private func integer(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue ?? value as? Int }
private func requiredInt(_ data: [String: Any], _ key: String, fallback: String? = nil) throws -> Int {
    if let value = integer(data[key]) { return value }
    if let fallback, let value = integer(data[fallback]) { return value }
    throw DomainError.generationFailedPermanent(referenceID: "probability-decode")
}
