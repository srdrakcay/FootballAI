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
    public let localeProvider: any LocaleProviding
    public let configurationService: any RemoteConfigurationService

    public init(fixtureRepository: any FixtureRepository, analysisRepository: any AnalysisRepository, userLibraryRepository: any UserLibraryRepository, creditWalletRepository: any CreditWalletRepository, creditPurchaseService: any CreditPurchaseService, localeProvider: any LocaleProviding, configurationService: any RemoteConfigurationService, authenticationService: (any AuthenticationService)? = nil) {
        self.fixtureRepository = fixtureRepository; self.analysisRepository = analysisRepository
        self.userLibraryRepository = userLibraryRepository
        self.creditWalletRepository = creditWalletRepository
        self.creditPurchaseService = creditPurchaseService
        self.localeProvider = localeProvider; self.configurationService = configurationService
        self.authenticationService = authenticationService
    }

    @discardableResult
    public static func bootstrapFirebase() -> Bool { FirebaseBootstrapper.configure() }

    public static func mock(now: Date = .now) -> AppCompositionRoot {
        let fixtures = SampleData.fixtures(now: now)
        return AppCompositionRoot(
            fixtureRepository: InMemoryFixtureRepository(fixtures: fixtures),
            analysisRepository: InMemoryAnalysisRepository(analyses: SampleData.analyses(fixtures: fixtures, now: now)),
            userLibraryRepository: InMemoryUserLibraryRepository(),
            creditWalletRepository: InMemoryCreditWalletRepository(),
            creditPurchaseService: InMemoryCreditPurchaseService(),
            localeProvider: InMemoryLocaleProvider(),
            configurationService: InMemoryRemoteConfigurationService()
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
            localeProvider: InMemoryLocaleProvider(),
            configurationService: configuration,
            authenticationService: authentication
        )
    }

    @discardableResult
    public func startSession() async throws -> String? {
        guard let authenticationService else { return nil }
        let uid = try await authenticationService.ensureAnonymousUser()
        let configuration: AppConfiguration
        do { configuration = try await configurationService.fetchAndActivate() }
        catch { configuration = await configurationService.bootstrap() }
        if !configuration.revenueCatPublicSDKKeyIOS.isEmpty {
            try? await creditPurchaseService.configure(publicAPIKey: configuration.revenueCatPublicSDKKeyIOS, appUserID: uid)
        }
        return uid
    }

    public func makeFixtureListViewModel() -> FixtureListViewModel {
        FixtureListViewModel(observeFixtures: DefaultObserveUpcomingFixturesUseCase(repository: fixtureRepository))
    }

    public func makeAnalysisViewModel(fixtureKey: FixtureKey, locale: SupportedLocale = .en) -> AnalysisViewModel {
        AnalysisViewModel(
            fixtureKey: fixtureKey, locale: locale,
            requestAnalysis: DefaultRequestAnalysisUseCase(repository: analysisRepository),
            observeAnalysis: DefaultObserveAnalysisUseCase(repository: analysisRepository),
            getAnalysis: DefaultGetLocalizedAnalysisUseCase(repository: analysisRepository)
        )
    }

    public func favoriteFixtureKeys() async throws -> Set<FixtureKey> {
        try await userLibraryRepository.favoriteFixtureKeys()
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

    public func signOut() async throws {
        await creditPurchaseService.resetUser()
        try await authenticationService?.signOut()
    }

    public func deleteAccount() async throws {
        await creditPurchaseService.resetUser()
        try await authenticationService?.deleteAccount()
    }
}

enum SampleData {
    static func fixtures(now: Date) -> [Fixture] {
        let championsLeague = Competition(id: .init(rawValue: "UCL"), name: "UEFA Champions League")
        let premierLeague = Competition(id: .init(rawValue: "PL"), name: "Premier League")
        let laLiga = Competition(id: .init(rawValue: "PD"), name: "La Liga")
        return [
            Fixture(
                key: .init(rawValue: "mock:2026:1"), version: 1, competition: championsLeague,
                homeTeam: Team(id: .init(rawValue: "home"), name: "North City"),
                awayTeam: Team(id: .init(rawValue: "away"), name: "South United"),
                kickoffAt: now.addingTimeInterval(4 * 3_600), status: .timed,
                latestSnapshotID: .init(rawValue: "snap_mock_1")
            ),
            Fixture(
                key: .init(rawValue: "mock:2026:2"), version: 1, competition: premierLeague,
                homeTeam: Team(id: .init(rawValue: "arsenal"), name: "London Red"),
                awayTeam: Team(id: .init(rawValue: "chelsea"), name: "London Blue"),
                kickoffAt: now.addingTimeInterval(25 * 3_600), status: .scheduled,
                latestSnapshotID: .init(rawValue: "snap_mock_2")
            ),
            Fixture(
                key: .init(rawValue: "mock:2026:3"), version: 1, competition: laLiga,
                homeTeam: Team(id: .init(rawValue: "madrid"), name: "Royal Madrid"),
                awayTeam: Team(id: .init(rawValue: "barcelona"), name: "Barcelona City"),
                kickoffAt: now.addingTimeInterval(48 * 3_600), status: .timed,
                latestSnapshotID: .init(rawValue: "snap_mock_3")
            )
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
}
