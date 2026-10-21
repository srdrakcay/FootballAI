import CoreDomain
import CoreLocalization
import FeatureAnalysis
import FeatureFixtures
import FirebaseAdapters
import Foundation

@MainActor
public final class AppCompositionRoot {
    private let fixtureRepository: any FixtureRepository
    private let analysisRepository: any AnalysisRepository
    private let userLibraryRepository: any UserLibraryRepository
    private let creditWalletRepository: any CreditWalletRepository
    private let creditPurchaseService: any CreditPurchaseService
    private let authenticationService: (any AuthenticationService)?
    private let analysisAccessService: any AnalysisAccessService
    private let aiProfileRepository: any AIProfileRepository
    public let localeProvider: any LocaleProviding
    public let configurationService: any RemoteConfigurationService
    /// True for the screenshot/preview build that runs on sample data.
    public let isMock: Bool

    public init(fixtureRepository: any FixtureRepository, analysisRepository: any AnalysisRepository, userLibraryRepository: any UserLibraryRepository, creditWalletRepository: any CreditWalletRepository, creditPurchaseService: any CreditPurchaseService, analysisAccessService: any AnalysisAccessService, aiProfileRepository: any AIProfileRepository, localeProvider: any LocaleProviding, configurationService: any RemoteConfigurationService, authenticationService: (any AuthenticationService)? = nil, isMock: Bool = false) {
        self.fixtureRepository = fixtureRepository; self.analysisRepository = analysisRepository
        self.userLibraryRepository = userLibraryRepository
        self.creditWalletRepository = creditWalletRepository
        self.creditPurchaseService = creditPurchaseService
        self.analysisAccessService = analysisAccessService
        self.aiProfileRepository = aiProfileRepository
        self.localeProvider = localeProvider; self.configurationService = configurationService
        self.authenticationService = authenticationService
        self.isMock = isMock
    }

    @discardableResult
    public static func bootstrapFirebase() -> Bool { FirebaseBootstrapper.configure() }

    public static func mock(now: Date = .now, profile: AIProfile? = SampleData.profile) -> AppCompositionRoot {
        let fixtures = SampleData.fixtures(now: now)
        let wallet = InMemoryCreditWalletRepository(
            value: CreditWallet(balance: 3, analysisCreditCost: 1),
            ledger: SampleData.ledger(now: now)
        )
        return AppCompositionRoot(
            fixtureRepository: InMemoryFixtureRepository(fixtures: fixtures),
            analysisRepository: InMemoryAnalysisRepository(analyses: SampleData.analyses(fixtures: fixtures, now: now)),
            userLibraryRepository: InMemoryUserLibraryRepository(
                favorites: Array(fixtures.prefix(1)),
                history: SampleData.history(fixtures: fixtures, now: now)
            ),
            creditWalletRepository: wallet,
            creditPurchaseService: InMemoryCreditPurchaseService(packages: [
                CreditPackage(id: "footballai_credits_5", title: "5", localizedPrice: "₺99,99", price: 99.99, localizedPricePerCredit: "₺20,00"),
                CreditPackage(id: "footballai_credits_10", title: "10", localizedPrice: "₺169,99", price: 169.99, localizedPricePerCredit: "₺17,00"),
            ]),
            analysisAccessService: InMemoryAnalysisAccessService(fixtures: fixtures, wallet: wallet, unlocked: Set(fixtures.prefix(2).map(\.key))),
            aiProfileRepository: InMemoryAIProfileRepository(profile: profile),
            localeProvider: InMemoryLocaleProvider(),
            configurationService: InMemoryRemoteConfigurationService(),
            isMock: true
        )
    }

    public static func live() -> AppCompositionRoot {
        let authentication = FirebaseAuthenticationService()
        let callable = FirebaseCallableTransport()
        let configuration = FirebaseRemoteConfigurationService()
        return AppCompositionRoot(
            fixtureRepository: FirebaseFixtureRepository(authentication: authentication, callable: callable),
            analysisRepository: FirebaseAnalysisRepository(authentication: authentication, callable: callable),
            userLibraryRepository: FirebaseUserLibraryRepository(authentication: authentication),
            creditWalletRepository: FirebaseCreditWalletRepository(authentication: authentication, configurationService: configuration),
            creditPurchaseService: RevenueCatCreditPurchaseService(),
            analysisAccessService: FirebaseAnalysisAccessService(authentication: authentication, callable: callable),
            aiProfileRepository: FirebaseAIProfileRepository(authentication: authentication, callable: callable),
            localeProvider: InMemoryLocaleProvider(),
            configurationService: configuration,
            authenticationService: authentication
        )
    }

    /// Signs in, activates config and returns wallet + AI profile from one bootstrap call.
    public func startSession(locale: SupportedLocale) async throws -> SessionInfo {
        guard let authenticationService else {
            async let wallet = creditWalletRepository.wallet()
            async let profile = aiProfileRepository.load()
            return SessionInfo(uid: "preview", wallet: try await wallet, aiProfile: try await profile)
        }
        async let configurationTask = activatedConfiguration()
        let session = try await authenticationService.session(locale: locale)
        let configuration = await configurationTask
        if !configuration.revenueCatPublicSDKKeyIOS.isEmpty {
            try? await creditPurchaseService.configure(publicAPIKey: configuration.revenueCatPublicSDKKeyIOS, appUserID: session.uid)
        }
        return session
    }

    private func activatedConfiguration() async -> AppConfiguration {
        do { return try await configurationService.fetchAndActivate() }
        catch { return await configurationService.bootstrap() }
    }

    public func observeWallet() -> AsyncStream<CreditWallet> { creditWalletRepository.observe() }

    public func creditLedger(limit: Int = 50) async throws -> [CreditLedgerEntry] {
        try await creditWalletRepository.ledger(limit: limit)
    }

    public func saveAIProfile(_ profile: AIProfile, locale: SupportedLocale) async throws {
        try await aiProfileRepository.save(profile, locale: locale)
    }

    public func openAnalysis(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> AnalysisAccess {
        try await analysisAccessService.open(fixtureKey: fixtureKey, locale: locale)
    }

    public func unlockAnalysis(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> UnlockedAnalysis {
        try await analysisAccessService.unlock(fixtureKey: fixtureKey, locale: locale)
    }

    public func fixtures(on day: Date, calendar: Calendar = .current) -> AsyncThrowingStream<[Fixture], any Error> {
        let from = calendar.startOfDay(for: day)
        let through = (calendar.date(byAdding: .day, value: 1, to: from) ?? from.addingTimeInterval(86_400)).addingTimeInterval(-0.001)
        return fixtureRepository.observeUpcoming(filter: FixtureFilter(from: from, through: through))
    }

    public func makeFixtureListViewModel() -> FixtureListViewModel {
        FixtureListViewModel(observeFixtures: DefaultObserveUpcomingFixturesUseCase(repository: fixtureRepository))
    }

    public func makeAnalysisViewModel(fixtureKey: FixtureKey, locale: SupportedLocale = .en) -> AnalysisViewModel {
        AnalysisViewModel(
            fixtureKey: fixtureKey, locale: locale,
            findExistingAnalysis: DefaultFindExistingAnalysisUseCase(repository: analysisRepository),
            requestAnalysis: DefaultRequestAnalysisUseCase(repository: analysisRepository),
            observeAnalysis: DefaultObserveAnalysisUseCase(repository: analysisRepository),
            getAnalysis: DefaultGetLocalizedAnalysisUseCase(repository: analysisRepository)
        )
    }

    public func favoriteFixtureKeys() async throws -> Set<FixtureKey> {
        try await userLibraryRepository.favoriteFixtureKeys()
    }

    public func fixtureInsights(fixtureKey: FixtureKey) async throws -> FixtureInsights {
        try await fixtureRepository.insights(id: fixtureKey)
    }

    public func favoriteFixtures() async throws -> [Fixture] {
        try await userLibraryRepository.favoriteFixtures()
    }

    public func setFavorite(_ fixture: Fixture, isFavorite: Bool) async throws {
        try await userLibraryRepository.setFavorite(fixture, isFavorite: isFavorite)
    }

    public func analysisHistory() async throws -> [AnalysisHistoryItem] {
        try await userLibraryRepository.analysisHistory()
    }

    public func creditWallet() async throws -> CreditWallet {
        try await creditWalletRepository.wallet()
    }

    public func creditPackages() async throws -> [CreditPackage] {
        try await creditPurchaseService.packages()
    }

    public func purchaseCredits(packageID: String) async throws -> CreditPurchaseResult {
        try await creditPurchaseService.purchase(packageID: packageID)
    }

    public func currentUserID() async -> String? {
        try? await authenticationService?.ensureAnonymousUser()
    }

    public func signOut() async throws {
        await creditPurchaseService.resetUser()
        try await authenticationService?.signOut()
    }

    public func deleteAccount() async throws {
        await creditPurchaseService.resetUser()
        try await authenticationService?.deleteAccount()
    }
}

public enum SampleData {
    public static let profile = AIProfile(
        favoriteTeam: FavoriteTeam(id: "home", name: "North City"),
        competitionIds: ["UCL", "PL"],
        style: .balanced,
        focusMarkets: [.matchResult, .goals]
    )

    static func ledger(now: Date) -> [CreditLedgerEntry] {
        [
            CreditLedgerEntry(id: "l4", kind: .analysisUnlock, delta: -1, balanceAfter: 3, label: "London Red – London Blue", createdAt: now.addingTimeInterval(-3_600)),
            CreditLedgerEntry(id: "l3", kind: .analysisUnlock, delta: -1, balanceAfter: 4, label: "Royal Madrid – Barcelona City", createdAt: now.addingTimeInterval(-2 * 86_400)),
            CreditLedgerEntry(id: "l2", kind: .purchase, delta: 5, balanceAfter: 5, label: nil, createdAt: now.addingTimeInterval(-3 * 86_400)),
            CreditLedgerEntry(id: "l1", kind: .analysisUnlock, delta: -1, balanceAfter: 0, label: "Coast Rovers – Midlands FC", createdAt: now.addingTimeInterval(-6 * 86_400)),
            CreditLedgerEntry(id: "l0", kind: .purchase, delta: 1, balanceAfter: 1, label: nil, createdAt: now.addingTimeInterval(-9 * 86_400)),
        ]
    }

    static func personal(for fixture: Fixture, locale: SupportedLocale) -> PersonalAnalysis {
        PersonalAnalysis(
            headline: "\(fixture.homeTeam.name) · 46 / 29 / 25",
            summary: "\(fixture.homeTeam.name) 46%, draw 29%, \(fixture.awayTeam.name) 25%. Over 2.5 goals 54%, both teams to score 57%.",
            forYou: "\(fixture.homeTeam.name): 46% to win, 29% draw.",
            keyFactors: [
                .init(section: .recentForm, text: "Recent form is reflected in the probabilities."),
                .init(section: .standings, text: "League positions were taken into account."),
            ],
            watchNote: "Lineups are not confirmed yet; probabilities may shift with team news.",
            locale: locale,
            favoriteSide: .home
        )
    }

    static func matchAnalysis(for fixture: Fixture, now: Date) -> MatchAnalysis? {
        let json = """
        {"analysisId":"ana_\(fixture.key.rawValue)","fixtureKey":"\(fixture.key.rawValue)","generatedAt":"\(ISO8601DateFormatter().string(from: now))","validUntil":"\(ISO8601DateFormatter().string(from: fixture.kickoffAt))",
        "markets":{"matchResult":{"homePct":46,"drawPct":29,"awayPct":25},"goals25":{"overPct":54,"underPct":46},"bothTeamsScore":{"yesPct":57,"noPct":43},
        "likelyScores":[{"home":1,"away":1,"pct":12},{"home":2,"away":1,"pct":10},{"home":1,"away":0,"pct":9}],"otherScoresPct":69},
        "confidence":{"level":"medium","scorePct":63},"limitations":["LINEUPS_UNAVAILABLE"]}
        """
        return try? JSONDecoder().decode(MatchAnalysis.self, from: Data(json.utf8))
    }

    static func fixtures(now: Date) -> [Fixture] {
        let championsLeague = Competition(id: .init(rawValue: "UCL"), name: "UEFA Champions League")
        let premierLeague = Competition(id: .init(rawValue: "PL"), name: "Premier League")
        let laLiga = Competition(id: .init(rawValue: "PD"), name: "La Liga")
        let eredivisie = Competition(id: .init(rawValue: "DED"), name: "Eredivisie", areaName: "Netherlands")
        let brasileirao = Competition(id: .init(rawValue: "BSA"), name: "Campeonato Brasileiro Série A", areaName: "Brazil")
        let superLig = Competition(id: .init(rawValue: "TSL"), name: "Süper Lig", areaName: "Turkey")
        let primeiraLiga = Competition(id: .init(rawValue: "PPL"), name: "Primeira Liga", areaName: "Portugal")
        let startOfDay = Calendar.current.startOfDay(for: now)
        func at(day: Int, hour: Int, minute: Int = 0) -> Date {
            startOfDay.addingTimeInterval(TimeInterval(day * 86_400 + hour * 3_600 + minute * 60))
        }
        func fixture(_ number: Int, _ competition: Competition, _ home: (String, String), _ away: (String, String), _ kickoff: Date, _ status: FixtureStatus, analysisSupported: Bool? = nil) -> Fixture {
            Fixture(
                key: .init(rawValue: "mock:2026:\(number)"), version: 1, competition: competition,
                homeTeam: Team(id: .init(rawValue: home.0), name: home.1),
                awayTeam: Team(id: .init(rawValue: away.0), name: away.1),
                kickoffAt: kickoff, status: status,
                latestSnapshotID: .init(rawValue: "snap_mock_\(number)"),
                analysisSupported: analysisSupported
            )
        }
        return [
            fixture(1, championsLeague, ("home", "North City"), ("away", "South United"), at(day: 0, hour: 21), .timed),
            fixture(2, premierLeague, ("arsenal", "London Red"), ("chelsea", "London Blue"), at(day: 1, hour: 20, minute: 30), .scheduled),
            fixture(3, laLiga, ("madrid", "Royal Madrid"), ("barcelona", "Barcelona City"), at(day: 2, hour: 21), .timed),
            fixture(4, premierLeague, ("coast", "Coast Rovers"), ("midlands", "Midlands FC"), at(day: 0, hour: 18, minute: 30), .scheduled),
            fixture(5, championsLeague, ("riverside", "Riverside"), ("harbor", "Harbor Town"), at(day: 0, hour: 19, minute: 45), .timed),
            fixture(6, laLiga, ("valley", "Sporting Valley"), ("atlas", "Atlas FC"), at(day: 0, hour: 22), .scheduled),
            fixture(7, eredivisie, ("canal", "Canal City"), ("tulip", "Tulip United"), at(day: 0, hour: 20, minute: 45), .timed),
            fixture(8, primeiraLiga, ("porto", "Porto Dragons"), ("lisbon", "Lisbon Eagles"), at(day: 0, hour: 21, minute: 15), .scheduled),
            fixture(9, brasileirao, ("rio", "Rio Samba"), ("sao", "São Paulo Stars"), at(day: 0, hour: 23, minute: 30), .scheduled),
            fixture(10, superLig, ("af:bosphorus", "Bosphorus FC"), ("af:anatolia", "Anatolia United"), at(day: 0, hour: 20), .scheduled, analysisSupported: false),
        ]
    }

    static func analyses(fixtures: [Fixture], now: Date) -> [Analysis] {
        guard let fixture = fixtures.first,
              let match = try? MatchResultProbabilities(home: 46, draw: 29, away: 25),
              let goals = try? BinaryProbabilities(yes: 54, no: 46),
              let btts = try? BinaryProbabilities(yes: 57, no: 43),
              let score = try? ScorelineProbability(home: 1, away: 1, percentage: 12),
              let markets = try? ProbabilityMarkets(matchResult: match, goalsOver25: goals, bothTeamsScore: btts, likelyScores: [score], otherScoresPercentage: 88),
              let confidence = try? Confidence(level: .medium, scorePercentage: 63)
        else { return [] }
        return [Analysis(
            id: .init(rawValue: "ana_mock_1"), fixtureKey: fixture.key, fixtureVersion: fixture.version,
            snapshotID: .init(rawValue: "snap_mock_1"), snapshotVersion: 1,
            schemaVersion: "2.0", promptVersion: "football-v2.1.0", modelVersion: "gemini-flash-default",
            generatedAt: now, validUntil: fixture.kickoffAt.addingTimeInterval(-3600), language: .en,
            markets: markets, confidence: confidence,
            rationale: [.init(code: "MOCK_FORM", text: "The available form data produces a balanced probability distribution.", evidenceRefs: ["sections.recentForm"])],
            dataAvailability: ["recentForm": .available, "lineups": .unavailable],
            limitations: ["LINEUPS_UNAVAILABLE"], moderationStatus: .passed
        )]
    }

    static func history(fixtures: [Fixture], now: Date) -> [AnalysisHistoryItem] {
        fixtures.prefix(2).enumerated().map { index, fixture in
            AnalysisHistoryItem(
                id: "history_mock_\(index + 1)",
                fixtureKey: fixture.key,
                analysisID: .init(rawValue: "ana_mock_\(index + 1)"),
                competitionName: fixture.competition.name,
                homeTeamName: fixture.homeTeam.name,
                awayTeamName: fixture.awayTeam.name,
                kickoffAt: fixture.kickoffAt,
                viewedAt: now.addingTimeInterval(TimeInterval(-index * 86_400)),
                generatedAt: now.addingTimeInterval(TimeInterval(-index * 86_400)),
                validUntil: index == 0 ? now.addingTimeInterval(10_800) : now.addingTimeInterval(-3_600),
                homeWinProbability: index == 0 ? 46 : 58,
                drawProbability: index == 0 ? 29 : 24,
                awayWinProbability: index == 0 ? 25 : 18
            )
        }
    }
}

/// Sample-data access service: unlocking spends from the in-memory wallet like the server does.
public actor InMemoryAnalysisAccessService: AnalysisAccessService {
    private let fixtures: [Fixture]
    private let wallet: InMemoryCreditWalletRepository
    private var unlocked: Set<FixtureKey>

    public init(fixtures: [Fixture], wallet: InMemoryCreditWalletRepository, unlocked: Set<FixtureKey> = []) {
        self.fixtures = fixtures
        self.wallet = wallet
        self.unlocked = unlocked
    }

    public func open(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> AnalysisAccess {
        let current = await wallet.wallet()
        guard unlocked.contains(fixtureKey) else { return .locked(current) }
        return .unlocked(try payload(fixtureKey, locale: locale, wallet: current))
    }

    public func unlock(fixtureKey: FixtureKey, locale: SupportedLocale) async throws -> UnlockedAnalysis {
        var current = await wallet.wallet()
        if !unlocked.contains(fixtureKey) {
            guard current.canAffordAnalysis else {
                throw DomainError.insufficientCredits(balance: current.available, required: current.analysisCreditCost)
            }
            try await Task.sleep(for: .milliseconds(900))
            current = CreditWallet(balance: current.balance - current.analysisCreditCost, analysisCreditCost: current.analysisCreditCost)
            await wallet.set(current)
            unlocked.insert(fixtureKey)
        }
        return try payload(fixtureKey, locale: locale, wallet: current)
    }

    private func payload(_ key: FixtureKey, locale: SupportedLocale, wallet: CreditWallet) throws -> UnlockedAnalysis {
        guard let fixture = fixtures.first(where: { $0.key == key }),
              let analysis = SampleData.matchAnalysis(for: fixture, now: .now) else { throw DomainError.fixtureNotFound }
        return UnlockedAnalysis(analysis: analysis, personal: SampleData.personal(for: fixture, locale: locale), wallet: wallet)
    }
}
