import CoreDomain
import FeatureAnalysis
import FeatureFixtures
import FootballAIAppCore
import SwiftUI

struct RootView: View {
    let compositionRoot: AppCompositionRoot
    @AppStorage("footballai.onboarding.completed.v1") private var completedOnboarding = false

    var body: some View {
        Group {
            if completedOnboarding {
                MainTabShell(compositionRoot: compositionRoot)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                OnboardingView { withAnimation(.easeInOut(duration: 0.45)) { completedOnboarding = true } }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, .autoupdatingCurrent)
        .task(id: completedOnboarding) {
            guard completedOnboarding else { return }
            _ = try? await compositionRoot.startSession()
        }
    }
}

// MARK: - Design system

private enum NeonTheme {
    static let background = Color(hex: 0x070511)
    static let surface = Color.white.opacity(0.075)
    static let surfaceStrong = Color(hex: 0x18112C).opacity(0.94)
    static let purple = Color(hex: 0x9B5CFF)
    static let violet = Color(hex: 0x6C3BFF)
    static let pink = Color(hex: 0xFF4FD8)
    static let cyan = Color(hex: 0x28E7FF)
    static let lime = Color(hex: 0xA8FF60)
    static let secondaryText = Color.white.opacity(0.62)
    static let gradient = LinearGradient(colors: [purple, pink], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private struct NeonBackground: View {
    var body: some View {
        ZStack {
            NeonTheme.background.ignoresSafeArea()
            RadialGradient(colors: [NeonTheme.purple.opacity(0.24), .clear], center: .topLeading, startRadius: 10, endRadius: 350)
                .ignoresSafeArea()
            RadialGradient(colors: [NeonTheme.cyan.opacity(0.12), .clear], center: .bottomTrailing, startRadius: 30, endRadius: 300)
                .ignoresSafeArea()
            Canvas { context, size in
                for index in 0..<28 {
                    let x = CGFloat((index * 73) % 101) / 100 * size.width
                    let y = CGFloat((index * 47) % 103) / 102 * size.height
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(0.12)))
                }
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}

private struct GlassCard: ViewModifier {
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background(NeonTheme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.18), NeonTheme.purple.opacity(0.16), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: NeonTheme.purple.opacity(0.10), radius: 22, y: 10)
    }
}

private extension View {
    func glassCard(radius: CGFloat = 24) -> some View { modifier(GlassCard(radius: radius)) }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

private func appText(_ turkish: String, _ english: String) -> String {
    Locale.autoupdatingCurrent.language.languageCode?.identifier == "tr" ? turkish : english
}

// MARK: - Onboarding

private struct OnboardingPage {
    let eyebrow: String
    let title: String
    let body: String
    let symbol: String
    let accent: Color
}

private struct OnboardingView: View {
    let completion: () -> Void
    @State private var selection = 0

    private let pages = [
        OnboardingPage(eyebrow: "FOOTBALL · INTELLIGENCE", title: appText("Maçları farklı\nbir gözle gör.", "See every match\ndifferently."), body: appText("Form, fikstür ve takım verilerini tek bir akıllı maç merkezinde keşfet.", "Explore form, fixtures, and team data in one intelligent match hub."), symbol: "sparkles", accent: NeonTheme.purple),
        OnboardingPage(eyebrow: "DATA DRIVEN", title: appText("Veriden doğan\nolasılıklar.", "Probabilities built\nfrom data."), body: appText("Her tahmin; güncel veriler, şeffaf gerekçeler ve açık sınırlamalarla sunulur.", "Every prediction comes with current data, transparent reasoning, and clear limitations."), symbol: "chart.xyaxis.line", accent: NeonTheme.cyan),
        OnboardingPage(eyebrow: "YOUR MATCH HUB", title: appText("Takip et. Analiz et.\nGeçmişe dön.", "Follow. Analyze.\nRevisit."), body: appText("Favori maçlarını bul, analiz geçmişini sakla ve deneyimini kişiselleştir.", "Find favorite matches, keep analysis history, and personalize your experience."), symbol: "bolt.fill", accent: NeonTheme.pink),
    ]

    var body: some View {
        ZStack {
            NeonBackground()
            VStack(spacing: 0) {
                HStack {
                    BrandMark(compact: false)
                    Spacer()
                    if selection < pages.count - 1 {
                        Button(appText("Atla", "Skip"), action: completion)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NeonTheme.secondaryText)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page, index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == selection ? NeonTheme.gradient : LinearGradient(colors: [.white.opacity(0.18)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: index == selection ? 34 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: selection)
                    }
                    Spacer()
                    Button {
                        if selection == pages.count - 1 { completion() }
                        else { withAnimation { selection += 1 } }
                    } label: {
                        HStack(spacing: 10) {
                            Text(selection == pages.count - 1 ? appText("Başlayalım", "Get started") : appText("Devam", "Continue"))
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 56)
                        .background(NeonTheme.gradient, in: Capsule())
                        .shadow(color: NeonTheme.purple.opacity(0.45), radius: 18)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer(minLength: 24)
            ZStack {
                Circle().fill(page.accent.opacity(0.10)).frame(width: 270, height: 270)
                Circle().stroke(page.accent.opacity(0.24), lineWidth: 1).frame(width: 220, height: 220)
                Circle().stroke(page.accent.opacity(0.12), lineWidth: 1).frame(width: 160, height: 160)
                Image(systemName: page.symbol)
                    .font(.system(size: 68, weight: .light))
                    .foregroundStyle(.white, page.accent)
                    .symbolRenderingMode(.palette)
                    .shadow(color: page.accent.opacity(0.85), radius: 24)
                ForEach(0..<3) { dot in
                    Circle().fill(dot == 1 ? NeonTheme.cyan : NeonTheme.pink)
                        .frame(width: dot == 1 ? 9 : 6)
                        .offset(x: CGFloat([-108, 102, -78][dot]), y: CGFloat([-42, 58, 104][dot]))
                        .shadow(color: page.accent, radius: 8)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                Text(page.eyebrow)
                    .font(.caption.weight(.bold))
                    .tracking(2.2)
                    .foregroundStyle(page.accent)
                Text(page.title)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .tracking(-1.5)
                    .foregroundStyle(.white)
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(NeonTheme.secondaryText)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Main navigation

private enum MainTab: CaseIterable {
    case matches, history, profile
    var title: String {
        switch self {
        case .matches: appText("Maçlar", "Matches")
        case .history: appText("Geçmiş", "History")
        case .profile: appText("Profil", "Profile")
        }
    }
    var symbol: String {
        switch self { case .matches: "soccerball"; case .history: "clock.arrow.circlepath"; case .profile: "person.crop.circle" }
    }
}

private struct MainTabShell: View {
    let compositionRoot: AppCompositionRoot
    @State private var selectedTab: MainTab = .matches
    @State private var showsTabBar = true

    var body: some View {
        ZStack(alignment: .bottom) {
            NeonBackground()
            Group {
                switch selectedTab {
                case .matches:
                    NavigationStack { MatchDashboardView(compositionRoot: compositionRoot, showsTabBar: $showsTabBar) }
                case .history:
                    NavigationStack { HistoryView(compositionRoot: compositionRoot) }
                case .profile:
                    NavigationStack { ProfileView(compositionRoot: compositionRoot) }
                }
            }
            .safeAreaPadding(.bottom, showsTabBar ? 124 : 0)

            if showsTabBar {
                NeonTabBar(selection: $selectedTab)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selectedTab)
    }
}

private struct NeonTabBar: View {
    @Binding var selection: MainTab
    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 19, weight: .semibold))
                            .symbolEffect(.bounce, value: selection == tab)
                        Text(tab.title).font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(selection == tab ? .white : NeonTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background {
                        if selection == tab {
                            Capsule().fill(NeonTheme.purple.opacity(0.20)).padding(.horizontal, 8)
                        }
                    }
                    .overlay(alignment: .top) {
                        if selection == tab { Capsule().fill(NeonTheme.gradient).frame(width: 24, height: 3) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.14), lineWidth: 1) }
        .shadow(color: .black.opacity(0.42), radius: 28, y: 12)
    }
}

// MARK: - Match dashboard

private enum MatchFilter: CaseIterable {
    case all, today, tomorrow, favorites
    var title: String {
        switch self {
        case .all: appText("Tümü", "All")
        case .today: appText("Bugün", "Today")
        case .tomorrow: appText("Yarın", "Tomorrow")
        case .favorites: appText("Favoriler", "Favorites")
        }
    }
}

private struct MatchDashboardView: View {
    let compositionRoot: AppCompositionRoot
    @Binding var showsTabBar: Bool
    @StateObject private var model: FixtureListViewModel
    @State private var selectedFilter: MatchFilter = .all
    @State private var selectedDate = Date.now
    @State private var favoriteIDs: Set<FixtureKey> = []
    @State private var favoriteFixtures: [Fixture] = []
    @State private var showsCalendar = false
    @State private var wallet = CreditWallet.defaultValue

    init(compositionRoot: AppCompositionRoot, showsTabBar: Binding<Bool>) {
        self.compositionRoot = compositionRoot
        _showsTabBar = showsTabBar
        _model = StateObject(wrappedValue: compositionRoot.makeFixtureListViewModel())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 22) {
                dashboardHeader
                quotaBanner
                dateSelector
                filterBar
                fixtureContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if case .idle = model.state { model.load(day: selectedDate) }
            async let storedIDs = compositionRoot.favoriteFixtureKeys()
            async let storedFixtures = compositionRoot.favoriteFixtures()
            favoriteIDs = (try? await storedIDs) ?? []
            favoriteFixtures = (try? await storedFixtures) ?? []
            wallet = (try? await compositionRoot.creditWallet()) ?? wallet
        }
        .onChange(of: selectedDate) { _, date in model.load(day: date) }
        .sheet(isPresented: $showsCalendar) {
            NavigationStack {
                DatePicker(appText("Maç tarihini seç", "Select match date"), selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(NeonTheme.purple)
                    .padding()
                    .navigationTitle(appText("Maç takvimi", "Match calendar"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button(appText("Bitti", "Done")) { showsCalendar = false } } }
            }
            .presentationDetents([.medium])
            .preferredColorScheme(.dark)
        }
    }

    private var dateSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appText("MAÇ TAKVİMİ", "MATCH CALENDAR")).font(.caption2.bold()).tracking(1.4).foregroundStyle(NeonTheme.cyan)
                    Text(selectedDate.formatted(Date.FormatStyle().day().month(.wide).year().locale(.autoupdatingCurrent))).font(.headline)
                }
                Spacer()
                Button { showsCalendar = true } label: {
                    Image(systemName: "calendar").font(.headline).frame(width: 42, height: 42).glassCard(radius: 14)
                }
                .foregroundStyle(NeonTheme.purple)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(calendarDays, id: \.self) { date in
                        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        Button { selectedDate = date; selectedFilter = .all } label: {
                            VStack(spacing: 5) {
                                Text(date.formatted(Date.FormatStyle().weekday(.abbreviated).locale(.autoupdatingCurrent))).font(.caption2.weight(.semibold))
                                Text(date.formatted(.dateTime.day())).font(.headline)
                            }
                            .foregroundStyle(selected ? .white : NeonTheme.secondaryText)
                            .frame(width: 52, height: 62)
                            .background(selected ? AnyShapeStyle(NeonTheme.gradient) : AnyShapeStyle(NeonTheme.surface), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
        }
        .padding(16).glassCard(radius: 22)
    }

    private var calendarDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: selectedDate)
        return (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var dashboardHeader: some View {
        HStack(spacing: 14) {
            BrandMark(compact: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(appText("İyi akşamlar", "Welcome back"))
                    .font(.caption)
                    .foregroundStyle(NeonTheme.secondaryText)
                Text(appText("Maç Merkezi", "Match Center"))
                    .font(.title2.bold())
            }
            Spacer()
        }
    }

    private var quotaBanner: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(.white.opacity(0.10), lineWidth: 7)
                Circle().trim(from: 0, to: 1).stroke(NeonTheme.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) { Text("\(wallet.balance)").font(.title2.bold()); Text(appText("kredi", "credits")).font(.caption2).foregroundStyle(NeonTheme.secondaryText) }
            }
            .frame(width: 74, height: 74)
            VStack(alignment: .leading, spacing: 7) {
                Label(appText("\(wallet.balance) kredin var", "You have \(wallet.balance) credits"), systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(appText("Bir maç analizi şu anda \(wallet.analysisCreditCost) kredi. Tutar uzaktan güvenli biçimde güncellenebilir.", "A match analysis currently costs \(wallet.analysisCreditCost) credits. The price can be updated remotely."))
                    .font(.caption)
                    .foregroundStyle(NeonTheme.secondaryText)
                    .lineSpacing(2)
            }
        }
        .padding(18)
        .background(NeonTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 26))
        .overlay { RoundedRectangle(cornerRadius: 26).stroke(NeonTheme.purple.opacity(0.35), lineWidth: 1) }
        .shadow(color: NeonTheme.purple.opacity(0.20), radius: 24)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MatchFilter.allCases, id: \.self) { filter in
                    Button(filter.title) {
                        selectedFilter = filter
                        if filter == .today { selectedDate = .now }
                        if filter == .tomorrow, let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) { selectedDate = tomorrow }
                    }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedFilter == filter ? .white : NeonTheme.secondaryText)
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(selectedFilter == filter ? AnyShapeStyle(NeonTheme.gradient) : AnyShapeStyle(NeonTheme.surface), in: Capsule())
                }
            }
        }
    }

    @ViewBuilder private var fixtureContent: some View {
        switch model.state {
        case .idle, .loading:
            if selectedFilter == .favorites, !favoriteFixtures.isEmpty { fixtureList(favoriteFixtures) }
            else { VStack(spacing: 14) { ForEach(0..<3) { _ in LoadingFixtureCard() } } }
        case .empty:
            if selectedFilter == .favorites, !favoriteFixtures.isEmpty { fixtureList(favoriteFixtures) }
            else { fixtureEmptyState }
        case .failed:
            if selectedFilter == .favorites, !favoriteFixtures.isEmpty { fixtureList(favoriteFixtures) }
            else { NeonEmptyState(symbol: "wifi.exclamationmark", title: appText("Maçlar yüklenemedi", "Matches could not be loaded"), message: appText("Bağlantını kontrol edip tekrar deneyebilirsin.", "Check your connection and try again."), actionTitle: appText("Tekrar dene", "Retry"), action: { model.load(day: selectedDate) }) }
        case .loaded(let fixtures):
            fixtureList(selectedFilter == .favorites ? favoriteFixtures : fixtures)
        }
    }

    private var fixtureEmptyState: some View {
        NeonEmptyState(
            symbol: selectedFilter == .favorites ? "heart.slash" : "calendar.badge.exclamationmark",
            title: selectedFilter == .favorites ? appText("Favori maçın yok", "No favorite matches") : appText("Bu tarihte maç yok", "No matches on this date"),
            message: selectedFilter == .favorites ? appText("Kalp simgesine dokunarak maçları buraya ekleyebilirsin.", "Tap the heart to add matches here.") : appText("Takvimden başka bir gün seçebilirsin.", "Choose another day from the calendar.")
        )
    }

    private func fixtureList(_ fixtures: [Fixture]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(selectedFilter == .favorites ? appText("Favori maçlar", "Favorite matches") : appText("Günün maçları", "Matches of the day")).font(.title3.bold())
                Spacer()
                Text("\(fixtures.count) \(appText("MAÇ", fixtures.count == 1 ? "MATCH" : "MATCHES"))").font(.caption2.bold()).tracking(1.2).foregroundStyle(NeonTheme.cyan)
            }
            if fixtures.isEmpty {
                fixtureEmptyState
            } else {
                ForEach(fixtures) { fixture in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink {
                            NeonFixtureDetailView(fixture: fixture, compositionRoot: compositionRoot, showsTabBar: $showsTabBar)
                        } label: {
                            FixtureCard(fixture: fixture, isFavorite: favoriteIDs.contains(fixture.key))
                        }
                        .buttonStyle(.plain)
                        Button { toggleFavorite(fixture) } label: {
                            Image(systemName: favoriteIDs.contains(fixture.key) ? "heart.fill" : "heart")
                                .foregroundStyle(favoriteIDs.contains(fixture.key) ? NeonTheme.pink : NeonTheme.secondaryText)
                                .frame(width: 42, height: 42)
                        }
                        .padding(.top, 5).padding(.trailing, 7)
                    }
                }
            }
        }
    }

    private func toggleFavorite(_ fixture: Fixture) {
        let shouldFavorite = !favoriteIDs.contains(fixture.key)
        if shouldFavorite {
            favoriteIDs.insert(fixture.key)
            favoriteFixtures.removeAll { $0.key == fixture.key }
            favoriteFixtures.append(fixture)
            favoriteFixtures.sort { $0.kickoffAt < $1.kickoffAt }
        } else {
            favoriteIDs.remove(fixture.key)
            favoriteFixtures.removeAll { $0.key == fixture.key }
        }
        Task {
            do { try await compositionRoot.setFavorite(fixture, isFavorite: shouldFavorite) }
            catch {
                if shouldFavorite {
                    favoriteIDs.remove(fixture.key)
                    favoriteFixtures.removeAll { $0.key == fixture.key }
                } else {
                    favoriteIDs.insert(fixture.key)
                    favoriteFixtures.append(fixture)
                    favoriteFixtures.sort { $0.kickoffAt < $1.kickoffAt }
                }
            }
        }
    }
}

private struct FixtureCard: View {
    let fixture: Fixture
    let isFavorite: Bool
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(fixture.competition.name.uppercased())
                    .font(.caption2.bold()).tracking(1.1).foregroundStyle(NeonTheme.cyan)
                Spacer().frame(minWidth: 44)
            }
            Label(fixture.kickoffAt.formatted(Date.FormatStyle().day().month(.abbreviated).hour().minute().locale(.autoupdatingCurrent)), systemImage: "clock")
                .font(.caption).foregroundStyle(NeonTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 13) {
                TeamBadge(name: fixture.homeTeam.name, color: NeonTheme.purple)
                Text(fixture.homeTeam.name).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading).lineLimit(2)
                VStack(spacing: 3) { Text("VS").font(.caption.bold()).foregroundStyle(NeonTheme.pink); Circle().fill(.white.opacity(0.18)).frame(width: 4, height: 4) }
                Text(fixture.awayTeam.name).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, alignment: .trailing).lineLimit(2)
                TeamBadge(name: fixture.awayTeam.name, color: NeonTheme.cyan)
            }
            HStack {
                Label(appText("Veriler hazır", "Data ready"), systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(NeonTheme.lime)
                Spacer()
                HStack(spacing: 6) { Text(appText("Maça git", "View match")); Image(systemName: "arrow.right") }
                    .font(.caption.weight(.semibold)).foregroundStyle(.white)
            }
        }
        .padding(18)
        .glassCard()
    }
}

private struct LoadingFixtureCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule().fill(.white.opacity(0.09)).frame(width: 130, height: 10)
            RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)).frame(height: 54)
            Capsule().fill(.white.opacity(0.07)).frame(width: 90, height: 9)
        }
        .padding(18).glassCard().redacted(reason: .placeholder)
    }
}

// MARK: - Match detail

private struct NeonFixtureDetailView: View {
    let fixture: Fixture
    let compositionRoot: AppCompositionRoot
    @Binding var showsTabBar: Bool
    @State private var isFavorite = false

    var body: some View {
        ZStack {
            NeonBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    matchHero
                    dataStrip
                    analysisCard
                    disclaimer
                }
                .padding(20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(appText("Maç analizi", "Match analysis"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(NeonTheme.background.opacity(0.9), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { toggleFavorite() } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart").foregroundStyle(isFavorite ? NeonTheme.pink : .white)
                }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.2)) { showsTabBar = false } }
        .onDisappear { withAnimation(.easeOut(duration: 0.2)) { showsTabBar = true } }
        .task {
            let favoriteIDs = try? await compositionRoot.favoriteFixtureKeys()
            isFavorite = favoriteIDs?.contains(fixture.key) ?? false
        }
    }

    private func toggleFavorite() {
        isFavorite.toggle()
        let value = isFavorite
        Task {
            do { try await compositionRoot.setFavorite(fixture, isFavorite: value) }
            catch { isFavorite.toggle() }
        }
    }

    private var matchHero: some View {
        VStack(spacing: 20) {
            Text(fixture.competition.name.uppercased()).font(.caption.bold()).tracking(1.5).foregroundStyle(NeonTheme.cyan)
            HStack(spacing: 16) {
                teamColumn(fixture.homeTeam, color: NeonTheme.purple)
                VStack(spacing: 8) {
                    Text("VS").font(.title3.bold()).foregroundStyle(NeonTheme.pink)
                    Text(fixture.kickoffAt, style: .time).font(.headline)
                    Text(fixture.kickoffAt, style: .date).font(.caption).foregroundStyle(NeonTheme.secondaryText)
                }
                .frame(width: 82)
                teamColumn(fixture.awayTeam, color: NeonTheme.cyan)
            }
        }
        .padding(.vertical, 26).padding(.horizontal, 18)
        .frame(maxWidth: .infinity).glassCard(radius: 28)
    }

    private func teamColumn(_ team: Team, color: Color) -> some View {
        VStack(spacing: 10) {
            TeamBadge(name: team.name, color: color, size: 68)
            Text(team.name).font(.subheadline.bold()).multilineTextAlignment(.center).lineLimit(2).frame(height: 38)
        }.frame(maxWidth: .infinity)
    }

    private var dataStrip: some View {
        HStack {
            DataPill(symbol: "chart.bar.fill", title: appText("Form", "Form"), state: appText("Hazır", "Ready"), color: NeonTheme.lime)
            Divider().overlay(.white.opacity(0.10))
            DataPill(symbol: "person.3.fill", title: appText("Kadro", "Lineup"), state: appText("Bekliyor", "Pending"), color: NeonTheme.pink)
            Divider().overlay(.white.opacity(0.10))
            DataPill(symbol: "clock.fill", title: appText("Güncellik", "Freshness"), state: appText("Canlı", "Live"), color: NeonTheme.cyan)
        }
        .padding(16).glassCard(radius: 20)
    }

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(appText("FootballAI Analizi", "FootballAI Analysis"), systemImage: "sparkles")
                        .font(.headline).foregroundStyle(.white)
                    Text(appText("1 ücretsiz hakkın kullanılacak", "Your 1 free analysis will be used")).font(.caption).foregroundStyle(NeonTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "brain.head.profile.fill").font(.title2).foregroundStyle(NeonTheme.purple)
            }
            Divider().overlay(.white.opacity(0.10))
            AnalysisStateView(viewModel: compositionRoot.makeAnalysisViewModel(fixtureKey: fixture.key, locale: SupportedLocale.resolve(identifier: Locale.autoupdatingCurrent.identifier)))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(NeonTheme.purple)
        }
        .padding(20).glassCard(radius: 24)
    }

    private var disclaimer: some View {
        Label(appText("Olasılıklar kesin sonuç veya bahis tavsiyesi değildir.", "Probabilities are not guaranteed outcomes or betting advice."), systemImage: "info.circle")
            .font(.caption).foregroundStyle(NeonTheme.secondaryText).padding(.horizontal, 8)
    }
}

private struct DataPill: View {
    let symbol: String; let title: String; let state: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(NeonTheme.secondaryText)
            Text(state).font(.caption2.bold()).foregroundStyle(.white)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - History

private enum HistoryFilter: CaseIterable {
    case all, valid, expired
    var title: String {
        switch self {
        case .all: appText("Tümü", "All")
        case .valid: appText("Geçerli", "Valid")
        case .expired: appText("Süresi dolan", "Expired")
        }
    }
}

private struct HistoryView: View {
    let compositionRoot: AppCompositionRoot
    @State private var filter: HistoryFilter = .all
    @State private var items: [AnalysisHistoryItem] = []
    @State private var isLoading = true
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(eyebrow: appText("ARŞİV", "ARCHIVE"), title: appText("Analiz geçmişin", "Analysis history"), subtitle: appText("Oluşturduğun analizlere yeniden göz at.", "Revisit analyses you have opened."))
                Picker(appText("Filtre", "Filter"), selection: $filter) {
                    ForEach(HistoryFilter.allCases, id: \.self) { item in Text(item.title).tag(item) }
                }
                .pickerStyle(.segmented)
                .colorMultiply(NeonTheme.purple)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(40)
                } else if filteredItems.isEmpty {
                    NeonEmptyState(symbol: "clock.arrow.circlepath", title: appText("Henüz analiz yok", "No analyses yet"), message: appText("Oluşturduğun veya daha önce açtığın analizler burada saklanacak.", "Analyses you generate or open will be stored here."))
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(appText("ANALİZLER", "ANALYSES")).font(.caption.bold()).tracking(1.3).foregroundStyle(NeonTheme.secondaryText)
                        ForEach(filteredItems) { item in HistoryCard(item: item) }
                    }
                }
            }
            .padding(20).padding(.bottom, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { items = (try? await compositionRoot.analysisHistory()) ?? []; isLoading = false }
    }

    private var filteredItems: [AnalysisHistoryItem] {
        switch filter {
        case .valid: items.filter { $0.validUntil > .now }
        case .expired: items.filter { $0.validUntil <= .now }
        default: items
        }
    }
}

private struct HistoryCard: View {
    let item: AnalysisHistoryItem
    private var isValid: Bool { item.validUntil > .now }
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label(isValid ? appText("Geçerli", "Valid") : appText("Süresi doldu", "Expired"), systemImage: isValid ? "checkmark.circle.fill" : "clock.badge.xmark")
                    .font(.caption.bold()).foregroundStyle(isValid ? NeonTheme.lime : NeonTheme.secondaryText)
                Spacer()
                Text(appText("AI ANALİZİ", "AI ANALYSIS")).font(.caption2.bold()).tracking(1).foregroundStyle(NeonTheme.purple)
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.homeTeamName).font(.headline)
                    Text(item.awayTeamName).font(.headline).foregroundStyle(NeonTheme.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.homeWinProbability.map { "%\($0)" } ?? "—").font(.title2.bold()).foregroundStyle(.white)
                    Text(appText("ev sahibi", "home")).font(.caption2).foregroundStyle(NeonTheme.secondaryText)
                }
            }
            Divider().overlay(.white.opacity(0.08))
            HStack { Text(item.competitionName).font(.caption).foregroundStyle(NeonTheme.secondaryText); Spacer(); Text(item.viewedAt, style: .date).font(.caption2).foregroundStyle(NeonTheme.purple) }
        }
        .padding(18).glassCard()
    }
}

// MARK: - Profile

private struct ProfileView: View {
    let compositionRoot: AppCompositionRoot
    @AppStorage("footballai.onboarding.completed.v1") private var completedOnboarding = true
    @State private var showsLogoutConfirmation = false
    @State private var showsDeleteConfirmation = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var wallet = CreditWallet.defaultValue
    @State private var showsCreditStore = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                ScreenHeader(
                    eyebrow: appText("HESABIN", "YOUR ACCOUNT"),
                    title: appText("Profil", "Profile"),
                    subtitle: appText("Hesabını, verilerini ve yasal belgeleri yönet.", "Manage your account, data, and legal documents.")
                )
                profileHero
                planCard
                settingsCard
                accountActions
            }
            .padding(20).padding(.bottom, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { wallet = (try? await compositionRoot.creditWallet()) ?? wallet }
        .sheet(isPresented: $showsCreditStore, onDismiss: {
            Task { wallet = (try? await compositionRoot.creditWallet()) ?? wallet }
        }) {
            CreditStoreView(compositionRoot: compositionRoot, wallet: wallet)
                .presentationDetents([.large])
                .preferredColorScheme(.dark)
        }
        .confirmationDialog(
            appText("Çıkış yapmak istiyor musun?", "Sign out?"),
            isPresented: $showsLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button(appText("Çıkış yap", "Sign out"), role: .destructive) { performSignOut() }
            Button(appText("Vazgeç", "Cancel"), role: .cancel) {}
        } message: {
            Text(appText("Anonim oturum bu cihazdan kaldırılır ve onboarding ekranına dönersin.", "The anonymous session will be removed from this device and you will return to onboarding."))
        }
        .alert(appText("Hesabı kalıcı olarak sil?", "Permanently delete account?"), isPresented: $showsDeleteConfirmation) {
            Button(appText("Vazgeç", "Cancel"), role: .cancel) {}
            Button(appText("Hesabı ve verileri sil", "Delete account and data"), role: .destructive) { performAccountDeletion() }
        } message: {
            Text(appText(
                "Profilin, kredilerin, favorilerin ve analiz geçmişin kalıcı olarak silinir. Bu işlem geri alınamaz.",
                "Your profile, credits, favorites, and analysis history will be permanently deleted. This cannot be undone."
            ))
        }
        .alert(appText("İşlem tamamlanamadı", "Action failed"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(appText("Tamam", "OK")) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var profileHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(NeonTheme.gradient).frame(width: 72, height: 72)
                Text("FA").font(.title2.bold()).foregroundStyle(.white)
            }
            .shadow(color: NeonTheme.purple.opacity(0.5), radius: 16)
            VStack(alignment: .leading, spacing: 5) {
                Text("Football Fan").font(.title3.bold())
                Text(appText("Anonim hesap", "Anonymous account")).font(.subheadline).foregroundStyle(NeonTheme.secondaryText)
                Label(appText("Firebase ile güvenli oturum", "Secure Firebase session"), systemImage: "lock.fill").font(.caption2).foregroundStyle(NeonTheme.lime)
            }
            Spacer()
        }
        .padding(20).glassCard()
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) { Text(appText("KREDİ CÜZDANI", "CREDIT WALLET")).font(.caption.bold()).tracking(1.4).foregroundStyle(NeonTheme.cyan); Text(appText("\(wallet.balance) kredi", "\(wallet.balance) credits")).font(.headline) }
                Spacer()
                Image(systemName: "bolt.circle.fill").font(.system(size: 34)).foregroundStyle(NeonTheme.purple)
            }
            HStack { Text(appText("Maç analizi maliyeti", "Match analysis cost")).font(.caption).foregroundStyle(NeonTheme.secondaryText); Spacer(); Text(appText("\(wallet.analysisCreditCost) kredi", "\(wallet.analysisCreditCost) credits")).font(.caption.bold()) }
            Button { showsCreditStore = true } label: {
                Label(appText("Kredi satın al", "Get credits"), systemImage: "plus.circle.fill")
                    .font(.subheadline.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 48).background(NeonTheme.gradient, in: Capsule())
            }
            Text(appText("Abonelik yok • Tek seferlik kredi paketleri", "No subscription • One-time credit packs")).font(.caption).foregroundStyle(NeonTheme.secondaryText).frame(maxWidth: .infinity)
        }
        .padding(20).glassCard()
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            NavigationLink { LegalDocumentView(document: .privacy) } label: {
                SettingsRow(symbol: "hand.raised.fill", title: appText("Gizlilik Politikası", "Privacy Policy"), value: nil, color: NeonTheme.lime)
            }
            .buttonStyle(.plain)
            divider
            NavigationLink { LegalDocumentView(document: .terms) } label: {
                SettingsRow(symbol: "doc.text.fill", title: appText("Kullanım Koşulları", "Terms of Use"), value: nil, color: NeonTheme.cyan)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18).glassCard()
    }

    private var accountActions: some View {
        VStack(spacing: 0) {
            Button { showsLogoutConfirmation = true } label: {
                actionRow(symbol: "rectangle.portrait.and.arrow.right", title: appText("Çıkış yap", "Sign out"), color: NeonTheme.purple)
            }
            .disabled(isWorking)
            divider
            Button { showsDeleteConfirmation = true } label: {
                actionRow(symbol: "trash.fill", title: appText("Hesabı sil", "Delete account"), color: .red)
            }
            .disabled(isWorking)
        }
        .padding(.horizontal, 18).glassCard()
        .overlay { if isWorking { ProgressView().tint(.white) } }
    }

    private func actionRow(symbol: String, title: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 28)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(color)
            Spacer()
        }
        .frame(height: 58)
        .contentShape(Rectangle())
    }

    private func performSignOut() {
        isWorking = true
        Task {
            do {
                try await compositionRoot.signOut()
                completedOnboarding = false
            } catch { errorMessage = appText("Çıkış yapılamadı. Lütfen tekrar dene.", "Could not sign out. Please try again.") }
            isWorking = false
        }
    }

    private func performAccountDeletion() {
        isWorking = true
        Task {
            do {
                try await compositionRoot.deleteAccount()
                completedOnboarding = false
            } catch { errorMessage = appText("Hesap silinemedi. Bağlantını kontrol edip tekrar dene.", "Could not delete the account. Check your connection and try again.") }
            isWorking = false
        }
    }

    private var divider: some View { Divider().overlay(.white.opacity(0.08)).padding(.leading, 44) }
}

private struct LegalSection: Identifiable {
    let id: String
    let title: String
    let paragraphs: [String]
}

private enum LegalDocument {
    case privacy, terms

    var title: String {
        switch self {
        case .privacy: appText("Gizlilik Politikası", "Privacy Policy")
        case .terms: appText("Kullanım Koşulları", "Terms of Use")
        }
    }

    var effectiveDate: String { appText("Yürürlük tarihi: 15 Temmuz 2026", "Effective date: July 15, 2026") }

    var sections: [LegalSection] {
        switch self {
        case .privacy: privacySections
        case .terms: termsSections
        }
    }

    private var privacySections: [LegalSection] {
        if Locale.autoupdatingCurrent.language.languageCode?.identifier == "tr" {
            return [
                .init(id: "scope", title: "1. Kapsam ve veri sorumlusu", paragraphs: ["Bu politika, com.footballai.predictions.com paket kimliğine sahip FootballAI iOS uygulamasını kapsar. FootballAI geliştiricisi, uygulama kapsamında işlenen kullanıcı verilerinden sorumludur. İletişim ve gizlilik talepleri App Store ürün sayfasındaki Destek bağlantısı üzerinden iletilebilir."]),
                .init(id: "data", title: "2. İşlediğimiz veriler", paragraphs: ["Uygulama; Firebase tarafından oluşturulan anonim kullanıcı kimliğini, tercih edilen sistem dilini, hesap oluşturma ve son görülme zamanlarını, ücretsiz kullanım kotasını, favori maçları ve analiz geçmişini saklar.", "Maç verileri football-data.org kaynağından sunucu üzerinden alınır. Firebase App Check, Firebase Authentication ve altyapı sağlayıcıları güvenlik amacıyla cihaz bütünlüğü sinyalleri, IP adresi ve teknik günlükleri işleyebilir. FootballAI reklam kimliği toplamaz ve kullanıcı konumuna erişmez."]),
                .init(id: "purpose", title: "3. Kullanım amaçları", paragraphs: ["Veriler; anonim oturumu sürdürebilmek, favorileri ve geçmişi cihazlar arası olmasa da yeniden kurulum sonrasında aynı Firebase hesabıyla sunmak, aylık kullanım hakkını uygulamak, maçları göstermek, kötüye kullanımı önlemek ve hizmet güvenliğini sağlamak için işlenir."]),
                .init(id: "providers", title: "4. Hizmet sağlayıcılar", paragraphs: ["Firebase/Google Cloud; kimlik doğrulama, veritabanı, sunucu fonksiyonları, uzaktan yapılandırma ve uygulama bütünlüğü hizmetlerini sağlar. football-data.org yalnızca sunucumuzdan gelen maç verisi isteklerini alır; anonim kullanıcı kimliği bu sağlayıcıyla paylaşılmaz.", "RevenueCat, tek seferlik kredi satın alımlarını doğrulamak için anonim hesap kimliğini, ürün ve işlem bilgilerini işler. FootballAI kişisel verileri satmaz, davranışsal reklam veya üçüncü taraflar arası takip amacıyla kullanmaz. Gemini henüz etkin değildir; etkinleştirilmeden önce bu politika ve App Store gizlilik beyanı güncellenecektir."]),
                .init(id: "retention", title: "5. Saklama ve silme", paragraphs: ["Hesap ve kullanıcıya bağlı veriler hesap silinene kadar saklanır. Profil ekranındaki Hesabı sil işlemi anonim Firebase hesabını; profil, kota, favoriler, geçmiş ve kullanıcıya bağlı istek kayıtlarıyla birlikte siler. Birden fazla kullanıcı için üretilmiş, kullanıcı kimliği içermeyen ortak maç analizleri hizmet bütünlüğü için saklanabilir.", "Çıkış yapmak hesabı sunucudan silmez; yalnızca bu cihazdaki oturumu kaldırır. Sağlayıcıların güvenlik ve operasyon günlükleri kendi sınırlı saklama sürelerine tabi olabilir."]),
                .init(id: "security", title: "6. Güvenlik ve uluslararası aktarım", paragraphs: ["Veriler aktarım sırasında şifrelenir ve Firebase güvenlik kuralları, App Check ve kimlik doğrulama ile korunur. Google Cloud hizmetlerinin çalışması nedeniyle veriler kullanıcının ülkesi dışındaki altyapılarda işlenebilir. Hiçbir teknik yöntem mutlak güvenlik garantisi vermez."]),
                .init(id: "rights", title: "7. Seçimleriniz ve haklarınız", paragraphs: ["Favorileri uygulama içinden kaldırabilir, çıkış yapabilir veya hesabınızı ve ilişkili verileri kalıcı olarak silebilirsiniz. Geçerli yerel mevzuat kapsamında erişim, düzeltme, silme veya itiraz taleplerinizi App Store Destek bağlantısı üzerinden iletebilirsiniz."]),
                .init(id: "children", title: "8. Çocuklar ve değişiklikler", paragraphs: ["FootballAI özellikle çocuklara yönelik değildir ve bilerek ad, e-posta veya doğum tarihi toplamaz. Bu politika veri uygulamalarımız değiştiğinde güncellenebilir; önemli değişiklikler yeni yürürlük tarihiyle uygulamada yayımlanır."])
            ]
        }
        return [
            .init(id: "scope", title: "1. Scope and controller", paragraphs: ["This policy applies to the FootballAI iOS app with bundle identifier com.footballai.predictions.com. The FootballAI developer is responsible for user data processed by the app. Privacy requests can be submitted through the Support link on the App Store product page."]),
            .init(id: "data", title: "2. Data we process", paragraphs: ["The app stores a Firebase-generated anonymous user identifier, system locale, account creation and last-seen times, free usage quota, favorite matches, and analysis history.", "Match data is requested server-side from football-data.org. Firebase App Check, Firebase Authentication, and infrastructure providers may process device-integrity signals, IP addresses, and technical logs for security. FootballAI does not access location or collect advertising identifiers."]),
            .init(id: "purpose", title: "3. Purposes", paragraphs: ["Data is processed to maintain the anonymous session, restore favorites and history for the same Firebase account, enforce monthly usage rights, display matches, prevent abuse, and secure the service."]),
            .init(id: "providers", title: "4. Service providers", paragraphs: ["Firebase/Google Cloud provides authentication, database, server functions, remote configuration, and app-integrity services. football-data.org receives server-side match-data requests and does not receive the anonymous user identifier.", "RevenueCat processes the anonymous account identifier and product and transaction information to validate one-time credit purchases. FootballAI does not sell personal data or use it for behavioral advertising or cross-service tracking. Gemini is not active; this policy and App Store disclosures will be updated before it is enabled."]),
            .init(id: "retention", title: "5. Retention and deletion", paragraphs: ["Account-linked data is retained until account deletion. Delete Account removes the anonymous Firebase account, profile, quota, favorites, history, and user-linked request records. Shared match analyses that contain no user identifier may be retained for service integrity.", "Signing out removes only the session from this device and does not delete server data. Provider security and operational logs may follow their own limited retention periods."]),
            .init(id: "security", title: "6. Security and transfers", paragraphs: ["Data is encrypted in transit and protected with Firebase Security Rules, App Check, and authentication. Google Cloud may process data outside the user’s country. No technical measure can guarantee absolute security."]),
            .init(id: "rights", title: "7. Your choices and rights", paragraphs: ["You can remove favorites, sign out, or permanently delete your account and associated data in the app. Applicable access, correction, deletion, or objection requests can be submitted through the App Store Support link."]),
            .init(id: "children", title: "8. Children and changes", paragraphs: ["FootballAI is not specifically directed to children and does not knowingly collect names, email addresses, or birth dates. This policy may be updated as data practices change; material changes will be shown with a new effective date."])
        ]
    }

    private var termsSections: [LegalSection] {
        if Locale.autoupdatingCurrent.language.languageCode?.identifier == "tr" {
            return [
                .init(id: "acceptance", title: "1. Koşulların kabulü", paragraphs: ["FootballAI’ı kullanarak bu Kullanım Koşullarını kabul edersiniz. Kabul etmiyorsanız uygulamayı kullanmayın. Anonim hesabınızı dilediğiniz zaman profil ekranından silebilirsiniz."]),
                .init(id: "service", title: "2. Hizmetin kapsamı", paragraphs: ["FootballAI maç fikstürlerini, favorileri, analiz geçmişini ve etkinleştirildiğinde yapay zekâ destekli olasılık analizlerini sunar. Özellikler, lig kapsamı ve ücretsiz haklar zaman içinde değişebilir."]),
                .init(id: "disclaimer", title: "3. Tahmin ve bahis uyarısı", paragraphs: ["Tüm analizler yalnızca bilgilendirme ve eğlence amaçlı olasılık tahminleridir. Kesin sonuç, finansal tavsiye veya bahis tavsiyesi değildir. Veriler eksik, gecikmeli ya da hatalı olabilir. Kararlarınızdan ve kayıplarınızdan siz sorumlusunuz."]),
                .init(id: "account", title: "4. Hesap ve ücretsiz kullanım", paragraphs: ["Uygulama varsayılan olarak anonim Firebase hesabı oluşturur. Hesabın ve cihazın güvenliğinden siz sorumlusunuz. Ücretsiz plan mevcut yapılandırmada aylık bir benzersiz analiz görüntüleme hakkı sunar; aynı maçın daha önce hazırlanmış analizi yeniden üretmeden gösterilebilir."]),
                .init(id: "acceptable", title: "5. Kabul edilebilir kullanım", paragraphs: ["Hizmeti tersine mühendislik, otomatik toplu istek, kota veya güvenlik mekanizmalarını aşma, API verilerini izinsiz yeniden dağıtma ya da hukuka aykırı amaçlarla kullanamazsınız. Kötüye kullanımda erişim sınırlandırılabilir."]),
                .init(id: "thirdparty", title: "6. Üçüncü taraf hizmetleri", paragraphs: ["Maç verileri football-data.org, altyapı Firebase/Google Cloud ve tek seferlik kredi satın alma doğrulaması RevenueCat tarafından sağlanır. Bu hizmetlerdeki kesinti, gecikme veya veri değişiklikleri FootballAI’ın kontrolü dışında olabilir. Gemini etkinleştirildiğinde ilgili koşullar ayrıca açıklanacaktır."]),
                .init(id: "ip", title: "7. Fikri mülkiyet", paragraphs: ["FootballAI adı, tasarımı ve uygulama kodu ilgili hak sahiplerine aittir. Takım, lig ve sağlayıcı adları kendi sahiplerinin markaları olabilir. Uygulama size kişisel ve devredilemez sınırlı kullanım hakkı verir."]),
                .init(id: "availability", title: "8. Kullanılabilirlik ve sorumluluk", paragraphs: ["Hizmet olduğu gibi sunulur; kesintisiz, hatasız veya belirli bir sonuca uygun olacağı garanti edilmez. Zorunlu hukuk kuralları saklı kalmak üzere FootballAI, uygulama kullanımından doğan dolaylı zarar veya kayıplardan sorumlu değildir."]),
                .init(id: "changes", title: "9. Değişiklikler ve sona erme", paragraphs: ["Hizmet veya bu koşullar güncellenebilir. Önemli değişiklikler yeni yürürlük tarihiyle uygulamada gösterilir. Koşulların ihlali halinde erişim durdurulabilir; kullanıcı hesabını silerek kullanımı her zaman sona erdirebilir. Uyuşmazlıklarda kullanıcının bulunduğu yerdeki zorunlu tüketici hakları korunur."])
            ]
        }
        return [
            .init(id: "acceptance", title: "1. Acceptance", paragraphs: ["By using FootballAI, you accept these Terms of Use. If you do not agree, do not use the app. You may delete your anonymous account from the profile screen at any time."]),
            .init(id: "service", title: "2. Service", paragraphs: ["FootballAI provides match schedules, favorites, analysis history, and—when enabled—AI-assisted probability analysis. Features, league coverage, and free allowances may change over time."]),
            .init(id: "disclaimer", title: "3. Predictions and betting disclaimer", paragraphs: ["All analyses are probabilistic information for informational and entertainment purposes only. They are not guaranteed outcomes, financial advice, or betting advice. Data may be incomplete, delayed, or incorrect. You remain responsible for your decisions and losses."]),
            .init(id: "account", title: "4. Account and free use", paragraphs: ["The app creates an anonymous Firebase account by default. You are responsible for device and account security. The current free plan provides one unique analysis view per month; an existing analysis for the same match may be reused without generating it again."]),
            .init(id: "acceptable", title: "5. Acceptable use", paragraphs: ["You may not reverse engineer the service, send automated bulk requests, bypass quota or security controls, redistribute API data without authorization, or use the service unlawfully. Access may be limited in response to abuse."]),
            .init(id: "thirdparty", title: "6. Third-party services", paragraphs: ["Match data is supplied by football-data.org, infrastructure by Firebase/Google Cloud, and one-time credit purchase validation by RevenueCat. Outages, delays, or data changes in those services may be outside FootballAI’s control. Gemini terms will be disclosed before that feature is enabled."]),
            .init(id: "ip", title: "7. Intellectual property", paragraphs: ["The FootballAI name, design, and application code belong to their respective rights holders. Team, league, and provider names may be trademarks of their owners. You receive a limited, personal, non-transferable right to use the app."]),
            .init(id: "availability", title: "8. Availability and liability", paragraphs: ["The service is provided as is, without a guarantee of uninterrupted or error-free operation or fitness for a particular outcome. Subject to mandatory law, FootballAI is not responsible for indirect damages or losses arising from app use."]),
            .init(id: "changes", title: "9. Changes and termination", paragraphs: ["The service and these terms may be updated. Material changes will appear with a new effective date. Access may be suspended for violations; you may stop using the service by deleting your account. Mandatory consumer rights in your location remain unaffected."])
        ]
    }
}

private struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ZStack {
            NeonBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text(document.effectiveDate).font(.caption).foregroundStyle(NeonTheme.cyan)
                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title).font(.headline)
                            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                                Text(paragraph).font(.subheadline).foregroundStyle(NeonTheme.secondaryText).lineSpacing(4)
                            }
                        }
                        .padding(18).glassCard(radius: 20)
                    }
                }
                .padding(20).padding(.bottom, 30)
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(NeonTheme.background.opacity(0.95), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct CreditStoreView: View {
    let compositionRoot: AppCompositionRoot
    let wallet: CreditWallet
    @Environment(\.dismiss) private var dismiss
    @State private var packages: [CreditPackage] = []
    @State private var selectedPackageID: String?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        VStack(spacing: 10) {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                                .font(.system(size: 54)).foregroundStyle(NeonTheme.gradient)
                            Text(appText("Sıradaki Maç Analizini Aç", "Unlock Your Next Match Analysis"))
                                .font(.title2.bold()).multilineTextAlignment(.center)
                            Text(appText("Mevcut bakiye: \(wallet.balance) kredi", "Current balance: \(wallet.balance) credits"))
                                .font(.subheadline).foregroundStyle(NeonTheme.cyan)
                            Text(appText("Abonelik yok • Tek seferlik satın alma", "No subscription • One-time purchase"))
                                .font(.caption).foregroundStyle(NeonTheme.secondaryText)
                        }

                        if isLoading {
                            ProgressView().tint(NeonTheme.purple).padding(40)
                        } else if packages.isEmpty {
                            Text(appText("RevenueCat Offering içinde henüz kredi paketi bulunamadı.", "No credit packages were found in the current RevenueCat Offering."))
                                .font(.subheadline).foregroundStyle(NeonTheme.secondaryText).multilineTextAlignment(.center).padding(24).glassCard()
                        } else {
                            VStack(spacing: 12) {
                                ForEach(packages) { package in
                                    Button { selectedPackageID = package.id } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: selectedPackageID == package.id ? "checkmark.circle.fill" : "circle")
                                                .font(.title2).foregroundStyle(selectedPackageID == package.id ? NeonTheme.lime : NeonTheme.secondaryText)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(package.title).font(.headline).foregroundStyle(.white)
                                                Text(package.id).font(.caption2).foregroundStyle(NeonTheme.secondaryText)
                                            }
                                            Spacer()
                                            Text(package.localizedPrice).font(.headline).foregroundStyle(NeonTheme.cyan)
                                        }
                                        .padding(18)
                                        .background(selectedPackageID == package.id ? NeonTheme.purple.opacity(0.22) : NeonTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                                        .overlay { RoundedRectangle(cornerRadius: 20).stroke(selectedPackageID == package.id ? NeonTheme.purple : .white.opacity(0.12)) }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Text(appText("Bir maç analizi şu anda \(wallet.analysisCreditCost) kredi.", "A match analysis currently costs \(wallet.analysisCreditCost) credits."))
                            .font(.footnote).foregroundStyle(NeonTheme.secondaryText).frame(maxWidth: .infinity).padding(14).glassCard(radius: 16)

                        if let message { Text(message).font(.footnote).foregroundStyle(NeonTheme.cyan).multilineTextAlignment(.center) }

                        Button { purchase() } label: {
                            Group {
                                if isPurchasing { ProgressView().tint(.white) }
                                else { Text(appText("Seçili kredi paketini satın al", "Purchase selected credit pack")) }
                            }
                            .font(.headline).frame(maxWidth: .infinity).frame(height: 52).background(NeonTheme.gradient, in: Capsule())
                        }
                        .disabled(selectedPackageID == nil || isPurchasing)
                        .opacity(selectedPackageID == nil ? 0.45 : 1)

                        Text(appText("Ödeme Apple kimliğine yansıtılır. Krediler tüketilebilir dijital ürünlerdir ve doğrulanan satın alma sonrasında hesabına eklenir.", "Payment is charged to your Apple ID. Credits are consumable digital items and are added after the purchase is verified."))
                            .font(.caption2).foregroundStyle(NeonTheme.secondaryText).multilineTextAlignment(.center)
                    }
                    .padding(20).padding(.bottom, 24)
                }
            }
            .navigationTitle(appText("Kredi Satın Al", "Get Credits"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(appText("Kapat", "Close")) { dismiss() } } }
            .task { await loadPackages() }
        }
    }

    private func loadPackages() async {
        isLoading = true
        do {
            packages = try await compositionRoot.creditPackages()
            selectedPackageID = packages.first?.id
        } catch {
            message = appText("Paketler yüklenemedi. RevenueCat Offering ayarını kontrol et.", "Packages could not be loaded. Check the RevenueCat Offering configuration.")
        }
        isLoading = false
    }

    private func purchase() {
        guard let selectedPackageID else { return }
        isPurchasing = true
        message = nil
        Task {
            do {
                let result = try await compositionRoot.purchaseCredits(packageID: selectedPackageID)
                message = result == .purchased
                    ? appText("Satın alma doğrulandı. Kredi bakiyesi sunucudan eşitleniyor.", "Purchase verified. Your credit balance is syncing from the server.")
                    : appText("Satın alma iptal edildi.", "Purchase cancelled.")
            } catch {
                message = appText("Satın alma tamamlanamadı. Lütfen tekrar dene.", "The purchase could not be completed. Please try again.")
            }
            isPurchasing = false
        }
    }
}

private struct SettingsRow: View {
    let symbol: String; let title: String; let value: String?; let color: Color
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 28)
            Text(title).font(.subheadline.weight(.medium))
            Spacer()
            if let value { Text(value).font(.caption).foregroundStyle(NeonTheme.secondaryText) }
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.white.opacity(0.25))
        }.frame(height: 58)
    }
}

// MARK: - Shared UI

private struct BrandMark: View {
    let compact: Bool
    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 13 : 11).fill(NeonTheme.gradient)
                Image(systemName: "bolt.fill").font(.system(size: compact ? 18 : 15, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: compact ? 44 : 36, height: compact ? 44 : 36)
            .shadow(color: NeonTheme.purple.opacity(0.55), radius: 12)
            if !compact { Text("FootballAI").font(.headline.bold()).foregroundStyle(.white) }
        }
    }
}

private struct TeamBadge: View {
    let name: String; let color: Color; var size: CGFloat = 46
    var initials: String { name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined() }
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.15))
            Circle().stroke(color.opacity(0.55), lineWidth: 1)
            Text(initials).font(.system(size: size * 0.28, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.28), radius: 10)
    }
}

private struct ScreenHeader: View {
    let eyebrow: String; let title: String; let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow).font(.caption.bold()).tracking(1.8).foregroundStyle(NeonTheme.purple)
            Text(title).font(.largeTitle.bold()).tracking(-1)
            Text(subtitle).font(.subheadline).foregroundStyle(NeonTheme.secondaryText)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
    }
}

private struct NeonEmptyState: View {
    let symbol: String; let title: String; let message: String
    var actionTitle: String? = nil; var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 36)).foregroundStyle(NeonTheme.purple)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(NeonTheme.secondaryText).multilineTextAlignment(.center)
            if let actionTitle, let action { Button(actionTitle, action: action).buttonStyle(.borderedProminent).tint(NeonTheme.purple) }
        }
        .frame(maxWidth: .infinity).padding(30).glassCard()
    }
}
