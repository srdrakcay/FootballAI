#if os(iOS)
import CoreDomain
import FootballAIAppCore
import Foundation
import Observation

extension SupportedLocale {
    /// The language the app UI is actually running in (per-app language setting respected).
    static var app: SupportedLocale {
        let preferred = Bundle.module.preferredLocalizations.first ?? Locale.current.identifier
        return SupportedLocale.resolve(identifier: preferred)
    }
}

/// Shared state for every tab. Loaded once per launch; tabs read it instead of refetching,
/// which is what makes screens open instantly.
@MainActor
@Observable
final class SessionStore {
    enum Phase: Equatable { case launching, ready, failed }

    private(set) var phase: Phase = .launching
    /// nil until the first server value arrives; UI shows a placeholder instead of a wrong number.
    private(set) var wallet: CreditWallet?
    private(set) var profile: AIProfile = .default
    private(set) var hasServerProfile = false
    private(set) var favoriteKeys: Set<FixtureKey> = []
    private(set) var favoriteFixtures: [Fixture] = []
    private(set) var history: [AnalysisHistoryItem] = []
    private(set) var historyLoaded = false
    private(set) var ledger: [CreditLedgerEntry] = []

    /// Analyses opened during this launch: reopening a match never waits for the network.
    private var unlockedCache: [FixtureKey: UnlockedAnalysis] = [:]
    private var insightsCache: [FixtureKey: FixtureInsights] = [:]
    private var walletObservation: Task<Void, Never>?
    let root: AppCompositionRoot
    let locale: SupportedLocale

    init(root: AppCompositionRoot, locale: SupportedLocale = .app) {
        self.root = root
        self.locale = locale
    }

    // MARK: Launch

    func start() async {
        guard phase != .ready else { return }
        do {
            let session = try await root.startSession(locale: locale)
            wallet = session.wallet
            if let serverProfile = session.aiProfile {
                profile = serverProfile
                hasServerProfile = true
            }
            phase = .ready
        } catch {
            phase = .failed
        }
        observeWallet()
        await refreshLibrary()
    }

    func retryStart() async {
        phase = .launching
        await start()
    }

    private func observeWallet() {
        walletObservation?.cancel()
        let stream = root.observeWallet()
        walletObservation = Task { [weak self] in
            for await value in stream {
                guard let self, !Task.isCancelled else { return }
                let previous = self.wallet
                self.wallet = value
                if previous != nil, previous?.balance != value.balance {
                    await self.refreshLedger()
                }
            }
        }
    }

    func refreshLibrary() async {
        async let favoritesKeys = try? root.favoriteFixtureKeys()
        async let favoritesList = try? root.favoriteFixtures()
        async let historyList = try? root.analysisHistory()
        async let ledgerList = try? root.creditLedger(limit: 50)
        let (keys, fixtures, items, entries) = await (favoritesKeys, favoritesList, historyList, ledgerList)
        if let keys { favoriteKeys = keys }
        if let fixtures { favoriteFixtures = fixtures }
        if let items { history = items; historyLoaded = true }
        if let entries { ledger = entries }
    }

    func refreshLedger() async {
        if let entries = try? await root.creditLedger(limit: 50) { ledger = entries }
    }

    // MARK: Profile

    func saveProfile(_ newValue: AIProfile) async throws {
        let previous = profile
        profile = newValue
        do {
            try await root.saveAIProfile(newValue, locale: locale)
            hasServerProfile = true
            // Personal layers depend on the profile; let reopened analyses be rewritten.
            unlockedCache.removeAll()
        } catch {
            profile = previous
            throw error
        }
    }

    // MARK: Favorites

    func isFavorite(_ fixture: Fixture) -> Bool { favoriteKeys.contains(fixture.key) }

    func toggleFavorite(_ fixture: Fixture) {
        let shouldFavorite = !favoriteKeys.contains(fixture.key)
        apply(fixture, favorite: shouldFavorite)
        Task {
            do { try await self.root.setFavorite(fixture, isFavorite: shouldFavorite) }
            catch { self.apply(fixture, favorite: !shouldFavorite) }
        }
    }

    private func apply(_ fixture: Fixture, favorite: Bool) {
        if favorite {
            favoriteKeys.insert(fixture.key)
            favoriteFixtures.removeAll { $0.key == fixture.key }
            favoriteFixtures.append(fixture)
            favoriteFixtures.sort { $0.kickoffAt < $1.kickoffAt }
        } else {
            favoriteKeys.remove(fixture.key)
            favoriteFixtures.removeAll { $0.key == fixture.key }
        }
    }

    // MARK: Analyses

    func historyItem(for key: FixtureKey) -> AnalysisHistoryItem? {
        history.first { $0.fixtureKey == key }
    }

    func cachedAnalysis(for key: FixtureKey) -> UnlockedAnalysis? { unlockedCache[key] }

    /// Known to be locked without asking the server (history is loaded and has no entry).
    func isKnownLocked(_ key: FixtureKey) -> Bool {
        historyLoaded && historyItem(for: key) == nil && unlockedCache[key] == nil
    }

    func open(_ fixture: Fixture) async throws -> AnalysisAccess {
        if let cached = unlockedCache[fixture.key] { return .unlocked(cached) }
        let access = try await root.openAnalysis(fixtureKey: fixture.key, locale: locale)
        switch access {
        case .unlocked(let value):
            unlockedCache[fixture.key] = value
            wallet = value.wallet
        case .locked(let value):
            wallet = value
        }
        return access
    }

    func unlock(_ fixture: Fixture) async throws -> UnlockedAnalysis {
        let value = try await root.unlockAnalysis(fixtureKey: fixture.key, locale: locale)
        unlockedCache[fixture.key] = value
        wallet = value.wallet
        insertHistory(fixture, value)
        Task { await self.refreshLedger() }
        return value
    }

    private func insertHistory(_ fixture: Fixture, _ value: UnlockedAnalysis) {
        guard historyItem(for: fixture.key) == nil else { return }
        let result = value.analysis.markets.matchResult
        history.insert(AnalysisHistoryItem(
            id: "local-\(fixture.key.rawValue)",
            fixtureKey: fixture.key,
            analysisID: .init(rawValue: value.analysis.analysisId),
            competitionName: fixture.competition.name,
            homeTeamName: fixture.homeTeam.name,
            awayTeamName: fixture.awayTeam.name,
            kickoffAt: fixture.kickoffAt,
            viewedAt: .now,
            generatedAt: value.analysis.generatedDate ?? .now,
            validUntil: value.analysis.validUntilDate ?? fixture.kickoffAt,
            homeWinProbability: result.homePct,
            drawProbability: result.drawPct,
            awayWinProbability: result.awayPct
        ), at: 0)
    }

    func insights(for key: FixtureKey) async throws -> FixtureInsights {
        if let cached = insightsCache[key] { return cached }
        let value = try await root.fixtureInsights(fixtureKey: key)
        insightsCache[key] = value
        return value
    }

    // MARK: Purchases

    func creditPackages() async throws -> [CreditPackage] { try await root.creditPackages() }

    func purchase(_ package: CreditPackage) async throws -> CreditPurchaseResult {
        try await root.purchaseCredits(packageID: package.id)
    }

    /// Waits (via the live wallet listener, not polling) until the balance rises above `previous`.
    func waitForCredits(above previous: Int, timeout: Duration = .seconds(45)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let balance = wallet?.balance, balance > previous { return true }
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return false }
        }
        return false
    }

    // MARK: Account

    func signOut() async throws {
        try await root.signOut()
        reset()
    }

    func deleteAccount() async throws {
        try await root.deleteAccount()
        reset()
    }

    private func reset() {
        walletObservation?.cancel()
        wallet = nil
        profile = .default
        hasServerProfile = false
        favoriteKeys = []
        favoriteFixtures = []
        history = []
        historyLoaded = false
        ledger = []
        unlockedCache = [:]
        insightsCache = [:]
        phase = .launching
    }
}
#endif
