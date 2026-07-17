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
            if showsAppPreview {
                MainTabShell(compositionRoot: compositionRoot)
            } else if showsStoreScreenshot {
                CreditStoreView(compositionRoot: compositionRoot, wallet: .defaultValue)
            } else if completedOnboarding {
                MainTabShell(compositionRoot: compositionRoot)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                OnboardingView { withAnimation(.easeInOut(duration: 0.45)) { completedOnboarding = true } }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, currentAppLocale)
        .task(id: completedOnboarding) {
            guard completedOnboarding else { return }
            _ = try? await compositionRoot.startSession()
        }
    }

    private var showsStoreScreenshot: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-footballai-screenshot-store")
#else
        false
#endif
    }

    private var showsAppPreview: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-footballai-app-preview")
#else
        false
#endif
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
    switch currentAppLocale.language.languageCode?.identifier {
    case "tr": turkish
    case "de": localizedInterfaceCopy[english]?.de ?? english
    case "fr": localizedInterfaceCopy[english]?.fr ?? english
    case "es": localizedInterfaceCopy[english]?.es ?? english
    default: english
    }
}

private var currentAppLocale: Locale {
#if DEBUG
    if ProcessInfo.processInfo.arguments.contains("-footballai-screenshot-tr") {
        return Locale(identifier: "tr_TR")
    }
    if ProcessInfo.processInfo.arguments.contains("-footballai-screenshot-de") {
        return Locale(identifier: "de_DE")
    }
    if ProcessInfo.processInfo.arguments.contains("-footballai-screenshot-fr") {
        return Locale(identifier: "fr_FR")
    }
    if ProcessInfo.processInfo.arguments.contains("-footballai-screenshot-es") {
        return Locale(identifier: "es_ES")
    }
#endif
    return .autoupdatingCurrent
}

private struct InterfaceTranslation {
    let de: String
    let fr: String
    let es: String
}

private let localizedInterfaceCopy: [String: InterfaceTranslation] = [
    "Matches": .init(de: "Spiele", fr: "Matchs", es: "Partidos"),
    "History": .init(de: "Verlauf", fr: "Historique", es: "Historial"),
    "Profile": .init(de: "Profil", fr: "Profil", es: "Perfil"),
    "Today": .init(de: "Heute", fr: "Aujourd’hui", es: "Hoy"),
    "Tomorrow": .init(de: "Morgen", fr: "Demain", es: "Mañana"),
    "Favorites": .init(de: "Favoriten", fr: "Favoris", es: "Favoritos"),
    "Match calendar": .init(de: "Spielkalender", fr: "Calendrier des matchs", es: "Calendario de partidos"),
    "Match Center": .init(de: "Spielzentrale", fr: "Centre des matchs", es: "Centro de partidos"),
    "Matches of the day": .init(de: "Spiele des Tages", fr: "Matchs du jour", es: "Partidos del día"),
    "Favorite matches": .init(de: "Favorisierte Spiele", fr: "Matchs favoris", es: "Partidos favoritos"),
    "Match analysis": .init(de: "Spielanalyse", fr: "Analyse du match", es: "Análisis del partido"),
    "NinetyLens Analysis": .init(de: "NinetyLens-Analyse", fr: "Analyse NinetyLens", es: "Análisis NinetyLens"),
    "Analysis history": .init(de: "Analyseverlauf", fr: "Historique des analyses", es: "Historial de análisis"),
    "Revisit analyses you have opened.": .init(de: "Öffne deine bisherigen Analysen erneut.", fr: "Retrouvez les analyses déjà consultées.", es: "Vuelve a consultar tus análisis."),
    "Privacy Policy": .init(de: "Datenschutzerklärung", fr: "Politique de confidentialité", es: "Política de privacidad"),
    "Terms of Use": .init(de: "Nutzungsbedingungen", fr: "Conditions d’utilisation", es: "Condiciones de uso"),
    "Sign out": .init(de: "Abmelden", fr: "Se déconnecter", es: "Cerrar sesión"),
    "Delete account": .init(de: "Account löschen", fr: "Supprimer le compte", es: "Eliminar cuenta"),
    "Delete account and data": .init(de: "Account und Daten löschen", fr: "Supprimer le compte et les données", es: "Eliminar cuenta y datos"),
    "Get Credits": .init(de: "Credits kaufen", fr: "Obtenir des crédits", es: "Obtener créditos"),
    "Purchase selected credit pack": .init(de: "Ausgewähltes Credit-Paket kaufen", fr: "Acheter le pack de crédits sélectionné", es: "Comprar el paquete seleccionado"),
    "No favorite matches": .init(de: "Keine Favoriten", fr: "Aucun match favori", es: "No hay partidos favoritos"),
    "No matches on this date": .init(de: "Keine Spiele an diesem Tag", fr: "Aucun match à cette date", es: "No hay partidos en esta fecha"),
    "Choose another day from the calendar.": .init(de: "Wähle einen anderen Tag im Kalender.", fr: "Choisissez un autre jour dans le calendrier.", es: "Elige otro día en el calendario."),
    "Retry": .init(de: "Erneut versuchen", fr: "Réessayer", es: "Reintentar"),
    "Skip": .init(de: "Überspringen", fr: "Passer", es: "Omitir"),
    "Continue": .init(de: "Weiter", fr: "Continuer", es: "Continuar"),
    "Get started": .init(de: "Loslegen", fr: "Commencer", es: "Empezar"),
    "See every match differently.": .init(de: "Sieh jedes Spiel neu.", fr: "Voyez chaque match autrement.", es: "Mira cada partido de otra forma."),
    "See every match\ndifferently.": .init(de: "Sieh jedes Spiel\nneu.", fr: "Voyez chaque match\nautrement.", es: "Mira cada partido\nde otra forma."),
    "Explore form, fixtures, and team data in one intelligent match hub.": .init(de: "Form, Spielpläne und Teamdaten in einer smarten Zentrale.", fr: "Forme, calendrier et données d’équipe dans un espace intelligent.", es: "Forma, calendario y datos de equipos en un centro inteligente."),
    "Welcome back": .init(de: "Willkommen zurück", fr: "Ravi de vous revoir", es: "Te damos la bienvenida"),
    "All": .init(de: "Alle", fr: "Tous", es: "Todos"),
    "MATCH CALENDAR": .init(de: "SPIELKALENDER", fr: "CALENDRIER", es: "CALENDARIO"),
    "You have 1 credit": .init(de: "Du hast 1 Credit", fr: "Vous avez 1 crédit", es: "Tienes 1 crédito"),
    "A match analysis currently costs 1 credit. The price can be updated remotely.": .init(de: "Eine Spielanalyse kostet aktuell 1 Credit. Der Preis kann zentral geändert werden.", fr: "Une analyse coûte actuellement 1 crédit. Ce coût peut être mis à jour à distance.", es: "Un análisis cuesta actualmente 1 crédito. El coste puede actualizarse a distancia."),
    "Data ready": .init(de: "Daten bereit", fr: "Données prêtes", es: "Datos listos"),
    "View match": .init(de: "Spiel öffnen", fr: "Voir le match", es: "Ver partido"),
    "ARCHIVE": .init(de: "ARCHIV", fr: "ARCHIVES", es: "ARCHIVO"),
    "YOUR ACCOUNT": .init(de: "DEIN KONTO", fr: "VOTRE COMPTE", es: "TU CUENTA"),
    "Manage your account, data, and legal documents.": .init(de: "Verwalte Konto, Daten und rechtliche Dokumente.", fr: "Gérez votre compte, vos données et les documents légaux.", es: "Gestiona tu cuenta, tus datos y los documentos legales."),
    "Anonymous account": .init(de: "Anonymes Konto", fr: "Compte anonyme", es: "Cuenta anónima"),
    "Secure Firebase session": .init(de: "Sichere Firebase-Sitzung", fr: "Session Firebase sécurisée", es: "Sesión segura de Firebase"),
    "CREDIT WALLET": .init(de: "CREDIT-GUTHABEN", fr: "SOLDE DE CRÉDITS", es: "SALDO DE CRÉDITOS"),
    "Get credits": .init(de: "Credits kaufen", fr: "Obtenir des crédits", es: "Obtener créditos"),
    "No subscription • One-time credit packs": .init(de: "Kein Abo • Einmalige Credit-Pakete", fr: "Sans abonnement • Packs ponctuels", es: "Sin suscripción • Paquetes únicos"),
    "Match analysis cost": .init(de: "Kosten pro Analyse", fr: "Coût d’une analyse", es: "Coste del análisis"),
    "1 credit": .init(de: "1 Credit", fr: "1 crédit", es: "1 crédito"),
    "credit": .init(de: "Credit", fr: "crédit", es: "crédito"),
    "credits": .init(de: "Credits", fr: "crédits", es: "créditos"),
]

private func creditText(_ count: Int) -> String {
    appText("\(count) kredi", "\(count) credit\(count == 1 ? "" : "s")")
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
    @State private var selectedTab: MainTab
    @State private var showsTabBar = true

    init(compositionRoot: AppCompositionRoot) {
        self.compositionRoot = compositionRoot
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        switch true {
        case arguments.contains("-footballai-screenshot-history"): _selectedTab = State(initialValue: .history)
        case arguments.contains("-footballai-screenshot-profile"): _selectedTab = State(initialValue: .profile)
        default: _selectedTab = State(initialValue: .matches)
        }
#else
        _selectedTab = State(initialValue: .matches)
#endif
    }

    var body: some View {
        ZStack {
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsTabBar {
                    NeonTabBar(selection: $selectedTab)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selectedTab)
        .task {
#if DEBUG
            guard ProcessInfo.processInfo.arguments.contains("-footballai-app-preview") else { return }
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.easeInOut(duration: 0.45)) { selectedTab = .history }
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.easeInOut(duration: 0.45)) { selectedTab = .profile }
#endif
        }
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
            .padding(.bottom, 90)
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
                    Text(selectedDate.formatted(Date.FormatStyle().day().month(.wide).year().locale(currentAppLocale))).font(.headline)
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
                                Text(date.formatted(Date.FormatStyle().weekday(.abbreviated).locale(currentAppLocale))).font(.caption2.weight(.semibold))
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
                VStack(spacing: -2) {
                    Text("\(wallet.balance)").font(.title2.bold())
                    Text(appText("kredi", wallet.balance == 1 ? "credit" : "credits"))
                        .font(.caption2)
                        .foregroundStyle(NeonTheme.secondaryText)
                }
            }
            .frame(width: 74, height: 74)
            VStack(alignment: .leading, spacing: 7) {
                Label(appText("\(wallet.balance) kredin var", "You have \(wallet.balance) credit\(wallet.balance == 1 ? "" : "s")"), systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(appText("Bir maç analizi şu anda \(wallet.analysisCreditCost) kredi. Tutar uzaktan güvenli biçimde güncellenebilir.", "A match analysis currently costs \(wallet.analysisCreditCost) credit\(wallet.analysisCreditCost == 1 ? "" : "s"). The price can be updated remotely."))
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
            Label(fixture.kickoffAt.formatted(Date.FormatStyle().day().month(.abbreviated).hour().minute().locale(currentAppLocale)), systemImage: "clock")
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
    @State private var wallet = CreditWallet.defaultValue
    @State private var showsCreditStore = false
    @State private var analysisRetryTrigger = 0
    @State private var insights: FixtureInsights?
    @State private var insightsError = false
    @State private var isLoadingInsights = true

    var body: some View {
        ZStack {
            NeonBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    matchHero
                    dataStrip
                    analysisCard
                    footballDataCard
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
            wallet = (try? await compositionRoot.creditWallet()) ?? wallet
            await loadInsights()
        }
        .sheet(isPresented: $showsCreditStore) {
            CreditStoreView(
                compositionRoot: compositionRoot,
                wallet: wallet,
                onWalletUpdated: { wallet = $0 },
                onPurchaseCompleted: { updatedWallet in
                    wallet = updatedWallet
                    guard updatedWallet.balance >= updatedWallet.analysisCreditCost else { return }
                    showsCreditStore = false
                    analysisRetryTrigger += 1
                }
            )
            .presentationDetents([.large])
            .preferredColorScheme(.dark)
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
                    Label(appText("NinetyLens Analizi", "NinetyLens Analysis"), systemImage: "sparkles")
                        .font(.headline).foregroundStyle(.white)
                    Text(appText(
                        "Bu analiz \(wallet.analysisCreditCost) kredi kullanır • Bakiye: \(wallet.balance)",
                        "This analysis uses \(creditText(wallet.analysisCreditCost)) • Balance: \(creditText(wallet.balance))"
                    ))
                    .font(.caption)
                    .foregroundStyle(wallet.balance >= wallet.analysisCreditCost ? NeonTheme.secondaryText : NeonTheme.pink)
                }
                Spacer()
                Image(systemName: "brain.head.profile.fill").font(.title2).foregroundStyle(NeonTheme.purple)
            }
            Divider().overlay(.white.opacity(0.10))
            AnalysisStateView(
                viewModel: compositionRoot.makeAnalysisViewModel(
                    fixtureKey: fixture.key,
                    locale: SupportedLocale.resolve(identifier: currentAppLocale.identifier)
                ),
                canAffordAnalysis: wallet.balance >= wallet.analysisCreditCost,
                retryTrigger: analysisRetryTrigger,
                onInsufficientCredits: { showsCreditStore = true },
                onAnalysisReady: {
                    Task {
                        wallet = (try? await compositionRoot.creditWallet()) ?? wallet
                        await loadInsights()
                    }
                }
            )
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(NeonTheme.purple)
        }
        .padding(20).glassCard(radius: 24)
    }

    @ViewBuilder
    private var footballDataCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(appText("Detaylı maç verileri", "Detailed match data"), systemImage: "chart.xyaxis.line")
                        .font(.headline)
                    Text(appText("football-data.org kaynaklı güncel istatistikler", "Current statistics powered by football-data.org"))
                        .font(.caption)
                        .foregroundStyle(NeonTheme.secondaryText)
                }
                Spacer()
                if isLoadingInsights { ProgressView().tint(NeonTheme.cyan) }
            }

            if let insights {
                if let form = insights.recentForm {
                    insightSectionTitle(appText("SON 5 MAÇ FORMU", "LAST 5 MATCH FORM"))
                    HStack(alignment: .top, spacing: 12) {
                        teamFormCard(name: fixture.homeTeam.name, form: form.home, accent: NeonTheme.purple)
                        teamFormCard(name: fixture.awayTeam.name, form: form.away, accent: NeonTheme.cyan)
                    }
                }

                if let standings = insights.standings {
                    Divider().overlay(.white.opacity(0.08))
                    insightSectionTitle(appText("PUAN DURUMU", "STANDINGS"))
                    standingRow(team: fixture.homeTeam.name, standing: standings.home, color: NeonTheme.purple)
                    standingRow(team: fixture.awayTeam.name, standing: standings.away, color: NeonTheme.cyan)
                }

                if !insights.headToHead.isEmpty {
                    Divider().overlay(.white.opacity(0.08))
                    insightSectionTitle(appText("İKİLİ KARŞILAŞMALAR", "HEAD TO HEAD"))
                    ForEach(Array(insights.headToHead.suffix(3).reversed())) { match in
                        insightMatchRow(match)
                    }
                }

                if insights.recentForm == nil, insights.standings == nil, insights.headToHead.isEmpty {
                    unavailableInsights
                }

                Text(appText("Veriler 30 dakika önbellekte tutulur.", "Data is cached for 30 minutes."))
                    .font(.caption2)
                    .foregroundStyle(NeonTheme.secondaryText)
            } else if insightsError {
                unavailableInsights
            } else {
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)).frame(height: 58)
                    RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)).frame(height: 42)
                }
                .redacted(reason: .placeholder)
            }
        }
        .padding(20)
        .glassCard(radius: 24)
    }

    private func insightSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption2.bold())
            .tracking(1.2)
            .foregroundStyle(NeonTheme.secondaryText)
    }

    private func teamFormCard(name: String, form: TeamRecentForm, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name).font(.caption.bold()).lineLimit(1)
            HStack(spacing: 5) {
                ForEach(Array(form.form.suffix(5).enumerated()), id: \.offset) { _, result in
                    Text(localizedForm(result))
                        .font(.caption2.bold())
                        .frame(width: 22, height: 22)
                        .background(formColor(result).opacity(0.18), in: Circle())
                        .foregroundStyle(formColor(result))
                }
            }
            Text(appText(
                "\(form.wins)G \(form.draws)B \(form.losses)M • \(form.goalsFor)-\(form.goalsAgainst) gol",
                "\(form.wins)W \(form.draws)D \(form.losses)L • \(form.goalsFor)-\(form.goalsAgainst) goals"
            ))
            .font(.caption2)
            .foregroundStyle(NeonTheme.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.22)))
    }

    private func standingRow(team: String, standing: TeamStanding, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(standing.position.map { "\($0)." } ?? "—")
                .font(.headline.bold())
                .foregroundStyle(color)
                .frame(width: 30)
            Text(team).font(.subheadline.bold()).lineLimit(1)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(standing.points.map { "\($0) \(appText("puan", "pts"))" } ?? "—").font(.subheadline.bold())
                Text(appText(
                    "\(standing.playedGames ?? 0) maç • Av. \(signed(standing.goalDifference))",
                    "\(standing.playedGames ?? 0) played • GD \(signed(standing.goalDifference))"
                ))
                .font(.caption2)
                .foregroundStyle(NeonTheme.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }

    private func insightMatchRow(_ match: FixtureInsightMatch) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(match.homeTeamName ?? "—").font(.caption.bold()).lineLimit(1)
                Text(match.awayTeamName ?? "—").font(.caption).foregroundStyle(NeonTheme.secondaryText).lineLimit(1)
            }
            Spacer()
            Text("\(match.homeGoals.map(String.init) ?? "—")  :  \(match.awayGoals.map(String.init) ?? "—")")
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(NeonTheme.lime)
            if let date = insightDate(match.utcDate) {
                Text(date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(NeonTheme.secondaryText)
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .padding(.vertical, 5)
    }

    private var unavailableInsights: some View {
        Label(
            appText("Bu maç için ayrıntılı istatistik henüz sağlanmıyor.", "Detailed statistics are not yet available for this match."),
            systemImage: "chart.bar.xaxis"
        )
        .font(.caption)
        .foregroundStyle(NeonTheme.secondaryText)
        .padding(.vertical, 8)
    }

    @MainActor
    private func loadInsights() async {
        isLoadingInsights = true
        do {
            insights = try await compositionRoot.fixtureInsights(fixtureKey: fixture.key)
            insightsError = false
        } catch {
            insightsError = true
        }
        isLoadingInsights = false
    }

    private func localizedForm(_ result: String) -> String {
        guard currentAppLocale.language.languageCode?.identifier == "tr" else { return result }
        switch result { case "W": return "G"; case "D": return "B"; case "L": return "M"; default: return result }
    }

    private func formColor(_ result: String) -> Color {
        switch result { case "W": NeonTheme.lime; case "D": NeonTheme.cyan; default: NeonTheme.pink }
    }

    private func signed(_ value: Int?) -> String {
        guard let value else { return "—" }
        return value > 0 ? "+\(value)" : String(value)
    }

    private func insightDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
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
            .padding(20).padding(.bottom, 90)
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
    @State private var userID: String?

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
            .padding(20).padding(.bottom, 90)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            wallet = (try? await compositionRoot.creditWallet()) ?? wallet
            userID = await compositionRoot.currentUserID()
        }
        .sheet(isPresented: $showsCreditStore, onDismiss: {
            Task { wallet = (try? await compositionRoot.creditWallet()) ?? wallet }
        }) {
            CreditStoreView(
                compositionRoot: compositionRoot,
                wallet: wallet,
                onWalletUpdated: { wallet = $0 },
                onPurchaseCompleted: { wallet = $0; showsCreditStore = false }
            )
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
                Text("NinetyLens Fan").font(.title3.bold())
                Text(appText("Anonim hesap", "Anonymous account")).font(.subheadline).foregroundStyle(NeonTheme.secondaryText)
                Label(appText("Firebase ile güvenli oturum", "Secure Firebase session"), systemImage: "lock.fill").font(.caption2).foregroundStyle(NeonTheme.lime)
                if let userID {
                    Text("ID: \(userID)").font(.caption2.monospaced()).foregroundStyle(NeonTheme.secondaryText).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
        }
        .padding(20).glassCard()
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appText("KREDİ CÜZDANI", "CREDIT WALLET")).font(.caption.bold()).tracking(1.4).foregroundStyle(NeonTheme.cyan)
                    Text(creditText(wallet.balance)).font(.headline)
                }
                Spacer()
                Image(systemName: "bolt.circle.fill").font(.system(size: 34)).foregroundStyle(NeonTheme.purple)
            }
            HStack {
                Text(appText("Maç analizi maliyeti", "Match analysis cost")).font(.caption).foregroundStyle(NeonTheme.secondaryText)
                Spacer()
                Text(creditText(wallet.analysisCreditCost)).font(.caption.bold())
            }
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

    var effectiveDate: String {
        switch Locale.autoupdatingCurrent.language.languageCode?.identifier {
        case "tr": "Yürürlük tarihi: 16 Temmuz 2026"
        case "de": "Gültig ab: 16. Juli 2026"
        case "fr": "Date d’entrée en vigueur : 16 juillet 2026"
        case "es": "Fecha de entrada en vigor: 16 de julio de 2026"
        default: "Effective date: July 16, 2026"
        }
    }

    var sections: [LegalSection] {
        switch self {
        case .privacy: privacySections
        case .terms: termsSections
        }
    }

    private var privacySections: [LegalSection] {
        let language = Locale.autoupdatingCurrent.language.languageCode?.identifier
        if language == "tr" {
            return [
                .init(id: "scope", title: "1. Kapsam ve veri sorumlusu", paragraphs: ["Bu politika, com.footballai.predictions.com paket kimliğine sahip NinetyLens iOS uygulamasını kapsar. Geliştirici ve veri sorumlusu Serdar Akçay’dır. Gizlilik ve destek talepleri srdrakcay25@gmail.com adresine iletilebilir."]),
                .init(id: "data", title: "2. İşlediğimiz veriler", paragraphs: ["Uygulama; Firebase tarafından oluşturulan anonim kullanıcı kimliğini, sistem dilini, hesap oluşturma ve son görülme zamanlarını, kredi bakiyesi ve kullanım kayıtlarını, favori maçları, analiz geçmişini ve Apple üzerinden doğrulanan ürün/işlem kayıtlarını işler.", "Firebase ve altyapı sağlayıcıları güvenlik amacıyla IP adresi, uygulama kurulumu veya cihaz bütünlüğü sinyalleri ile teknik günlükleri işleyebilir. Kart numarası veya Apple ödeme bilgileri NinetyLens’e ulaşmaz. Uygulama kesin konuma, kişilere, fotoğraflara, mikrofona veya reklam kimliğine erişmez."]),
                .init(id: "purpose", title: "3. Kullanım amaçları", paragraphs: ["Veriler; anonim oturumu sürdürmek, favorileri ve geçmişi göstermek, kredi satın alımlarını doğrulamak, kredi kullanımını uygulamak, mükerrer analiz ve işlemleri önlemek, fikstürleri sunmak, dolandırıcılık ve kötüye kullanımı azaltmak ve hizmet güvenliğini sağlamak için işlenir. Veriler reklam, profil oluşturma veya üçüncü taraflar arası takip amacıyla kullanılmaz."]),
                .init(id: "providers", title: "4. Hizmet sağlayıcılar", paragraphs: ["Firebase/Google Cloud kimlik doğrulama, veritabanı, sunucu fonksiyonları, uzaktan yapılandırma ve App Check hizmetlerini sağlar. RevenueCat anonim hesap kimliği, ürün kimliği ve işlem durumunu kredi satın alımlarını doğrulamak için işler. Apple ödemeyi işler.", "football-data.org yalnızca sunucu tarafından istenen maç verilerini sağlar ve kullanıcı kimliğini almaz. Google Gemini’ye yalnızca maç ve takım bağlamı gönderilir; anonim kullanıcı kimliği, satın alma bilgisi veya cihaz verisi gönderilmez."]),
                .init(id: "retention", title: "5. Saklama ve silme", paragraphs: ["Hesaba bağlı profil, kredi, favori ve geçmiş verileri hesap silinene kadar saklanır. Profil > Hesabı sil işlemi anonim Firebase hesabını ve kullanıcıyla bağlantılı verileri siler. Kullanıcı kimliği içermeyen ortak maç analizleri; yeniden üretimi önlemek, hizmet bütünlüğü ve maliyet kontrolü için saklanabilir.", "Çıkış yapmak sunucudaki hesabı silmez, yalnızca cihazdaki oturumu kaldırır. Apple, Google ve RevenueCat güvenlik, işlem ve mevzuat kayıtlarını kendi politikaları kapsamında daha uzun süre saklayabilir."]),
                .init(id: "security", title: "6. Güvenlik ve uluslararası aktarım", paragraphs: ["Veriler aktarım sırasında şifrelenir ve Firebase güvenlik kuralları, App Check ve kimlik doğrulama ile korunur. Google Cloud hizmetlerinin çalışması nedeniyle veriler kullanıcının ülkesi dışındaki altyapılarda işlenebilir. Hiçbir teknik yöntem mutlak güvenlik garantisi vermez."]),
                .init(id: "rights", title: "7. Seçimleriniz ve haklarınız", paragraphs: ["Favorileri kaldırabilir, çıkış yapabilir veya hesabınızı ve ilişkili verileri uygulama içinden kalıcı olarak silebilirsiniz. Erişim, düzeltme, silme, kısıtlama veya itiraz talepleri için srdrakcay25@gmail.com adresine yazabilirsiniz. Satın alma iadeleri Apple’ın iade süreci üzerinden yönetilir."]),
                .init(id: "children", title: "8. Çocuklar ve değişiklikler", paragraphs: ["NinetyLens özellikle çocuklara yönelik değildir ve bilerek ad, e-posta veya doğum tarihi toplamaz. Bu politika veri uygulamalarımız değiştiğinde güncellenebilir; önemli değişiklikler yeni yürürlük tarihiyle uygulamada yayımlanır."])
            ]
        }
        if language == "de" {
            return [
                .init(id: "scope", title: "1. Geltungsbereich und Verantwortlicher", paragraphs: ["Diese Erklärung gilt für die NinetyLens iOS-App mit der Bundle-ID com.footballai.predictions.com. Verantwortlicher Entwickler ist Serdar Akçay. Datenschutz- und Supportanfragen können an srdrakcay25@gmail.com gesendet werden."]),
                .init(id: "data", title: "2. Verarbeitete Daten", paragraphs: ["Die App verarbeitet eine von Firebase erzeugte anonyme Benutzer-ID, Systemsprache, Kontozeiten, Credit-Guthaben und -Nutzung, Favoriten, Analyseverlauf sowie von Apple bestätigte Produkt- und Transaktionsdaten.", "Firebase und Infrastrukturpartner können IP-Adresse, Installations- oder Geräteintegritätssignale und technische Protokolle zur Sicherheit verarbeiten. NinetyLens erhält keine Karten- oder Apple-Zahlungsdaten und greift nicht auf Standort, Kontakte, Fotos, Mikrofon oder Werbe-ID zu."]),
                .init(id: "purpose", title: "3. Zwecke", paragraphs: ["Die Daten werden für Sitzung, Favoriten, Verlauf, Kaufprüfung, Credit-Verwendung, Vermeidung doppelter Analysen, Spielpläne, Betrugsprävention und Sicherheit genutzt. Sie werden nicht für Werbung, Profiling oder Tracking über Dienste hinweg verwendet."]),
                .init(id: "providers", title: "4. Dienstleister", paragraphs: ["Firebase/Google Cloud stellt Authentifizierung, Datenbank, Serverfunktionen, Remote Config und App Check bereit. RevenueCat verarbeitet anonyme Konto-, Produkt- und Transaktionsdaten zur Kaufprüfung; Apple verarbeitet die Zahlung.", "football-data.org liefert serverseitig Spieldaten. An Google Gemini werden nur Spiel- und Teamdaten übertragen, keine anonyme Benutzer-ID, Kauf- oder Gerätedaten."]),
                .init(id: "retention", title: "5. Speicherung und Löschung", paragraphs: ["Kontobezogene Daten bleiben bis zur Kontolöschung gespeichert. Profil > Account löschen entfernt das anonyme Firebase-Konto und zugehörige Daten. Geteilte Analysen ohne Benutzer-ID können zur Vermeidung erneuter Generierung und für die Dienstintegrität gespeichert bleiben.", "Abmelden löscht nur die Sitzung auf dem Gerät. Apple, Google und RevenueCat können Sicherheits- und Transaktionsprotokolle nach ihren eigenen Richtlinien aufbewahren."]),
                .init(id: "security", title: "6. Sicherheit und Übermittlung", paragraphs: ["Daten werden bei der Übertragung verschlüsselt und durch Authentifizierung, Firebase Security Rules und App Check geschützt. Cloud-Anbieter können Daten außerhalb Ihres Landes verarbeiten. Absolute Sicherheit kann nicht garantiert werden."]),
                .init(id: "rights", title: "7. Ihre Rechte", paragraphs: ["Sie können Favoriten entfernen, sich abmelden oder Konto und verknüpfte Daten in der App löschen. Für Auskunft, Berichtigung, Löschung, Einschränkung oder Widerspruch schreiben Sie an srdrakcay25@gmail.com. Rückerstattungen werden über Apple abgewickelt."]),
                .init(id: "children", title: "8. Kinder und Änderungen", paragraphs: ["NinetyLens richtet sich nicht speziell an Kinder und erhebt wissentlich keine Namen, E-Mail-Adressen oder Geburtsdaten. Wesentliche Änderungen werden mit einem neuen Gültigkeitsdatum veröffentlicht."])
            ]
        }
        if language == "fr" {
            return [
                .init(id: "scope", title: "1. Champ d’application et responsable", paragraphs: ["Cette politique s’applique à l’app iOS NinetyLens, identifiant com.footballai.predictions.com. Le développeur responsable est Serdar Akçay. Les demandes peuvent être envoyées à srdrakcay25@gmail.com."]),
                .init(id: "data", title: "2. Données traitées", paragraphs: ["L’app traite un identifiant utilisateur anonyme Firebase, la langue système, les dates du compte, le solde et l’utilisation des crédits, les favoris, l’historique d’analyse ainsi que les données de produit et de transaction validées par Apple.", "Firebase et les fournisseurs d’infrastructure peuvent traiter l’adresse IP, des signaux d’installation ou d’intégrité de l’appareil et des journaux techniques à des fins de sécurité. NinetyLens ne reçoit aucune donnée de carte ou de paiement Apple et n’accède pas à la localisation, aux contacts, aux photos, au microphone ni à l’identifiant publicitaire."]),
                .init(id: "purpose", title: "3. Finalités", paragraphs: ["Les données servent à maintenir la session, afficher favoris et historique, valider les achats, appliquer les crédits, éviter les analyses dupliquées, fournir les calendriers, prévenir la fraude et sécuriser le service. Elles ne servent ni à la publicité, ni au profilage, ni au suivi interservices."]),
                .init(id: "providers", title: "4. Prestataires", paragraphs: ["Firebase/Google Cloud fournit l’authentification, la base de données, les fonctions serveur, Remote Config et App Check. RevenueCat traite l’identifiant anonyme, le produit et l’état de transaction pour valider les achats ; Apple traite le paiement.", "football-data.org fournit les données de match côté serveur. Seules les données de match et d’équipe sont envoyées à Google Gemini, sans identifiant utilisateur, donnée d’achat ou donnée d’appareil."]),
                .init(id: "retention", title: "5. Conservation et suppression", paragraphs: ["Les données liées au compte sont conservées jusqu’à sa suppression. Profil > Supprimer le compte efface le compte Firebase anonyme et les données liées. Les analyses partagées sans identifiant utilisateur peuvent être conservées pour éviter une nouvelle génération et protéger l’intégrité du service.", "La déconnexion retire seulement la session de l’appareil. Apple, Google et RevenueCat peuvent conserver leurs journaux de sécurité et de transaction selon leurs propres politiques."]),
                .init(id: "security", title: "6. Sécurité et transferts", paragraphs: ["Les données sont chiffrées en transit et protégées par l’authentification, les règles Firebase et App Check. Les fournisseurs cloud peuvent traiter des données hors de votre pays. Aucune mesure ne garantit une sécurité absolue."]),
                .init(id: "rights", title: "7. Vos droits", paragraphs: ["Vous pouvez retirer des favoris, vous déconnecter ou supprimer votre compte et ses données dans l’app. Pour l’accès, la rectification, l’effacement, la limitation ou l’opposition, écrivez à srdrakcay25@gmail.com. Les remboursements sont gérés par Apple."]),
                .init(id: "children", title: "8. Enfants et modifications", paragraphs: ["NinetyLens ne cible pas spécifiquement les enfants et ne collecte pas sciemment leur nom, adresse e-mail ou date de naissance. Toute modification importante sera publiée avec une nouvelle date d’entrée en vigueur."])
            ]
        }
        if language == "es" {
            return [
                .init(id: "scope", title: "1. Alcance y responsable", paragraphs: ["Esta política se aplica a la app iOS NinetyLens con identificador com.footballai.predictions.com. El desarrollador responsable es Serdar Akçay. Las solicitudes pueden enviarse a srdrakcay25@gmail.com."]),
                .init(id: "data", title: "2. Datos tratados", paragraphs: ["La app trata un identificador anónimo de Firebase, idioma del sistema, fechas de la cuenta, saldo y uso de créditos, favoritos, historial de análisis y datos de producto y transacción validados por Apple.", "Firebase y los proveedores de infraestructura pueden tratar la dirección IP, señales de instalación o integridad del dispositivo y registros técnicos por seguridad. NinetyLens no recibe datos de tarjeta o pago de Apple ni accede a ubicación, contactos, fotos, micrófono o identificador publicitario."]),
                .init(id: "purpose", title: "3. Finalidades", paragraphs: ["Los datos se usan para mantener la sesión, mostrar favoritos e historial, validar compras, aplicar créditos, evitar análisis duplicados, ofrecer calendarios, prevenir fraude y proteger el servicio. No se usan para publicidad, perfiles ni seguimiento entre servicios."]),
                .init(id: "providers", title: "4. Proveedores", paragraphs: ["Firebase/Google Cloud ofrece autenticación, base de datos, funciones de servidor, Remote Config y App Check. RevenueCat trata el identificador anónimo, producto y estado de transacción para validar compras; Apple procesa el pago.", "football-data.org proporciona datos de partidos desde el servidor. A Google Gemini solo se envían datos del partido y los equipos, sin identificador de usuario, compras ni datos del dispositivo."]),
                .init(id: "retention", title: "5. Conservación y eliminación", paragraphs: ["Los datos vinculados a la cuenta se conservan hasta su eliminación. Perfil > Eliminar cuenta borra la cuenta anónima de Firebase y sus datos. Los análisis compartidos sin identificador pueden conservarse para evitar regeneraciones y proteger la integridad del servicio.", "Cerrar sesión solo elimina la sesión del dispositivo. Apple, Google y RevenueCat pueden conservar registros de seguridad y transacciones según sus políticas."]),
                .init(id: "security", title: "6. Seguridad y transferencias", paragraphs: ["Los datos se cifran en tránsito y se protegen con autenticación, reglas de Firebase y App Check. Los proveedores cloud pueden tratar datos fuera de tu país. Ninguna medida garantiza seguridad absoluta."]),
                .init(id: "rights", title: "7. Tus derechos", paragraphs: ["Puedes quitar favoritos, cerrar sesión o eliminar la cuenta y sus datos desde la app. Para acceso, rectificación, eliminación, limitación u oposición, escribe a srdrakcay25@gmail.com. Los reembolsos se gestionan mediante Apple."]),
                .init(id: "children", title: "8. Menores y cambios", paragraphs: ["NinetyLens no está dirigida específicamente a menores y no recopila conscientemente nombres, correos o fechas de nacimiento. Los cambios importantes se publicarán con una nueva fecha de entrada en vigor."])
            ]
        }
        return [
            .init(id: "scope", title: "1. Scope and controller", paragraphs: ["This policy applies to the NinetyLens iOS app with bundle identifier com.footballai.predictions.com. The responsible developer is Serdar Akçay. Privacy and support requests can be sent to srdrakcay25@gmail.com."]),
            .init(id: "data", title: "2. Data we process", paragraphs: ["The app processes a Firebase-generated anonymous user identifier, system language, account timestamps, credit balance and usage records, favorite matches, analysis history, and Apple-validated product and transaction records.", "Firebase and infrastructure providers may process IP address, app-installation or device-integrity signals, and technical logs for security. NinetyLens never receives card details or Apple payment credentials and does not access precise location, contacts, photos, microphone, or advertising identifiers."]),
            .init(id: "purpose", title: "3. Purposes", paragraphs: ["Data is used to maintain the anonymous session, display favorites and history, validate purchases, enforce credit usage, prevent duplicate analyses and transactions, provide fixtures, reduce fraud and abuse, and secure the service. It is not used for advertising, profiling, or cross-service tracking."]),
            .init(id: "providers", title: "4. Service providers", paragraphs: ["Firebase/Google Cloud provides authentication, database, server functions, Remote Config, and App Check. RevenueCat processes the anonymous account identifier, product identifier, and transaction status to validate credit purchases; Apple processes the payment.", "football-data.org supplies match data through server-side requests and does not receive the user identifier. Only match and team context is sent to Google Gemini; the anonymous user identifier, purchase information, and device data are not sent to Gemini."]),
            .init(id: "retention", title: "5. Retention and deletion", paragraphs: ["Account-linked profile, credit, favorite, and history data is retained until account deletion. Profile > Delete Account removes the anonymous Firebase account and user-linked data. Shared match analyses containing no user identifier may be retained to prevent duplicate generation, control cost, and protect service integrity.", "Signing out removes only the session from the device. Apple, Google, and RevenueCat may retain security, transaction, and compliance records under their own policies."]),
            .init(id: "security", title: "6. Security and transfers", paragraphs: ["Data is encrypted in transit and protected with Firebase Security Rules, App Check, and authentication. Google Cloud may process data outside the user’s country. No technical measure can guarantee absolute security."]),
            .init(id: "rights", title: "7. Your choices and rights", paragraphs: ["You can remove favorites, sign out, or permanently delete your account and associated data in the app. For access, correction, deletion, restriction, or objection requests, email srdrakcay25@gmail.com. Purchase refunds are handled through Apple’s refund process."]),
            .init(id: "children", title: "8. Children and changes", paragraphs: ["NinetyLens is not specifically directed to children and does not knowingly collect names, email addresses, or birth dates. This policy may be updated as data practices change; material changes will be shown with a new effective date."])
        ]
    }

    private var termsSections: [LegalSection] {
        if Locale.autoupdatingCurrent.language.languageCode?.identifier == "tr" {
            return [
                .init(id: "acceptance", title: "1. Koşulların kabulü", paragraphs: ["NinetyLens’i kullanarak bu Kullanım Koşullarını kabul edersiniz. Kabul etmiyorsanız uygulamayı kullanmayın. Anonim hesabınızı dilediğiniz zaman profil ekranından silebilirsiniz."]),
                .init(id: "service", title: "2. Hizmetin kapsamı", paragraphs: ["NinetyLens maç fikstürlerini, favorileri, analiz geçmişini ve yapay zekâ destekli olasılık analizlerini sunar. Özellikler, lig kapsamı, kredi maliyeti ve ücretsiz haklar zaman içinde değişebilir."]),
                .init(id: "disclaimer", title: "3. Tahmin ve bahis uyarısı", paragraphs: ["Tüm analizler yalnızca bilgilendirme ve eğlence amaçlı olasılık tahminleridir. Kesin sonuç, finansal tavsiye veya bahis tavsiyesi değildir. Veriler eksik, gecikmeli ya da hatalı olabilir. Kararlarınızdan ve kayıplarınızdan siz sorumlusunuz."]),
                .init(id: "account", title: "4. Hesap ve ücretsiz kullanım", paragraphs: ["Uygulama varsayılan olarak anonim Firebase hesabı oluşturur. Hesabın ve cihazın güvenliğinden siz sorumlusunuz. Ücretsiz plan mevcut yapılandırmada aylık bir benzersiz analiz görüntüleme hakkı sunar; aynı maçın daha önce hazırlanmış analizi yeniden üretmeden gösterilebilir."]),
                .init(id: "purchases", title: "5. Krediler ve satın almalar", paragraphs: ["Krediler Apple’ın uygulama içi satın alma sistemiyle sunulan tüketilebilir dijital ürünlerdir. Satın alınan kredilerin süresi dolmaz. Apple tarafından onaylanan bir iade, ilgili kullanılmamış kredilerin bakiyeden kaldırılmasına neden olabilir. Ödemeler ve iadeler Apple tarafından işlenir."]),
                .init(id: "acceptable", title: "6. Kabul edilebilir kullanım", paragraphs: ["Hizmeti tersine mühendislik, otomatik toplu istek, kota veya güvenlik mekanizmalarını aşma, API verilerini izinsiz yeniden dağıtma ya da hukuka aykırı amaçlarla kullanamazsınız. Kötüye kullanımda erişim sınırlandırılabilir."]),
                .init(id: "thirdparty", title: "7. Üçüncü taraf hizmetleri", paragraphs: ["Maç verileri football-data.org, altyapı Firebase/Google Cloud, yapay zekâ analizi Google Gemini ve tek seferlik kredi satın alma doğrulaması RevenueCat tarafından sağlanır. Bu hizmetlerdeki kesinti, gecikme veya veri değişiklikleri NinetyLens’in kontrolü dışında olabilir."]),
                .init(id: "ip", title: "8. Fikri mülkiyet", paragraphs: ["NinetyLens adı, tasarımı ve uygulama kodu ilgili hak sahiplerine aittir. Takım, lig ve sağlayıcı adları kendi sahiplerinin markaları olabilir. Uygulama size kişisel ve devredilemez sınırlı kullanım hakkı verir."]),
                .init(id: "availability", title: "9. Kullanılabilirlik ve sorumluluk", paragraphs: ["Hizmet olduğu gibi sunulur; kesintisiz, hatasız veya belirli bir sonuca uygun olacağı garanti edilmez. Zorunlu hukuk kuralları saklı kalmak üzere NinetyLens, uygulama kullanımından doğan dolaylı zarar veya kayıplardan sorumlu değildir."]),
                .init(id: "changes", title: "10. Değişiklikler ve sona erme", paragraphs: ["Hizmet veya bu koşullar güncellenebilir. Önemli değişiklikler yeni yürürlük tarihiyle uygulamada gösterilir. Koşulların ihlali halinde erişim durdurulabilir; kullanıcı hesabını silerek kullanımı her zaman sona erdirebilir. Uyuşmazlıklarda kullanıcının bulunduğu yerdeki zorunlu tüketici hakları korunur."])
            ]
        }
        if Locale.autoupdatingCurrent.language.languageCode?.identifier == "de" {
            return [
                .init(id: "acceptance", title: "1. Annahme und Dienst", paragraphs: ["Mit der Nutzung von NinetyLens akzeptieren Sie diese Bedingungen. Die App bietet Spielpläne, Favoriten, Verlauf und KI-gestützte Wahrscheinlichkeitsanalysen."]),
                .init(id: "disclaimer", title: "2. Analysehinweis", paragraphs: ["Analysen sind nur Information und Unterhaltung. Sie garantieren kein Ergebnis und sind keine Finanz- oder Wettberatung. Daten können verspätet, unvollständig oder falsch sein."]),
                .init(id: "purchases", title: "3. Credits und Käufe", paragraphs: ["Credits sind verbrauchbare digitale Güter, die über Apples In-App-Kaufsystem angeboten werden. Gekaufte Credits verfallen nicht. Eine von Apple bestätigte Rückerstattung kann die entsprechenden ungenutzten Credits entfernen."]),
                .init(id: "acceptable", title: "4. Zulässige Nutzung", paragraphs: ["Sicherheits-, Credit- oder Kontrollen dürfen nicht umgangen, automatisierte Massenanfragen nicht gesendet und API-Daten nicht unbefugt weitergegeben werden."]),
                .init(id: "account", title: "5. Konto und Löschung", paragraphs: ["Die App verwendet standardmäßig ein anonymes Firebase-Konto. Sie können das Konto und verknüpfte Daten jederzeit im Profil dauerhaft löschen."]),
                .init(id: "changes", title: "6. Verfügbarkeit und Rechte", paragraphs: ["Der Dienst wird ohne Garantie eines bestimmten Ergebnisses bereitgestellt. Änderungen werden mit einem neuen Gültigkeitsdatum angezeigt. Zwingende Verbraucherrechte an Ihrem Wohnort bleiben unberührt."])
            ]
        }
        if Locale.autoupdatingCurrent.language.languageCode?.identifier == "fr" {
            return [
                .init(id: "acceptance", title: "1. Acceptation et service", paragraphs: ["En utilisant NinetyLens, vous acceptez ces conditions. L’app fournit calendrier, favoris, historique et analyses probabilistes assistées par IA."]),
                .init(id: "disclaimer", title: "2. Avertissement", paragraphs: ["Les analyses sont fournies uniquement à titre informatif et de divertissement. Elles ne garantissent aucun résultat et ne constituent ni un conseil financier ni un conseil de pari."]),
                .init(id: "purchases", title: "3. Crédits et achats", paragraphs: ["Les crédits sont des biens numériques consommables proposés via les achats intégrés Apple. Les crédits achetés n’expirent pas. Un remboursement confirmé par Apple peut retirer les crédits non utilisés correspondants."]),
                .init(id: "acceptable", title: "4. Utilisation autorisée", paragraphs: ["Il est interdit de contourner les contrôles de sécurité ou de crédits, d’envoyer des requêtes automatisées en masse ou de redistribuer les données API sans autorisation."]),
                .init(id: "account", title: "5. Compte et suppression", paragraphs: ["L’app utilise par défaut un compte Firebase anonyme. Vous pouvez supprimer définitivement le compte et ses données depuis le profil."]),
                .init(id: "changes", title: "6. Disponibilité et droits", paragraphs: ["Le service est fourni sans garantie de résultat particulier. Les modifications importantes seront affichées avec une nouvelle date. Les droits impératifs des consommateurs restent applicables."])
            ]
        }
        if Locale.autoupdatingCurrent.language.languageCode?.identifier == "es" {
            return [
                .init(id: "acceptance", title: "1. Aceptación y servicio", paragraphs: ["Al usar NinetyLens aceptas estas condiciones. La app ofrece calendario, favoritos, historial y análisis probabilísticos asistidos por IA."]),
                .init(id: "disclaimer", title: "2. Aviso", paragraphs: ["Los análisis son solo informativos y de entretenimiento. No garantizan resultados ni constituyen asesoramiento financiero o de apuestas."]),
                .init(id: "purchases", title: "3. Créditos y compras", paragraphs: ["Los créditos son bienes digitales consumibles ofrecidos mediante compras integradas de Apple. Los créditos comprados no caducan. Un reembolso confirmado por Apple puede retirar los créditos no utilizados correspondientes."]),
                .init(id: "acceptable", title: "4. Uso permitido", paragraphs: ["No se pueden eludir controles de seguridad o créditos, enviar solicitudes automatizadas masivas ni redistribuir datos de API sin autorización."]),
                .init(id: "account", title: "5. Cuenta y eliminación", paragraphs: ["La app usa por defecto una cuenta anónima de Firebase. Puedes eliminar permanentemente la cuenta y sus datos desde el perfil."]),
                .init(id: "changes", title: "6. Disponibilidad y derechos", paragraphs: ["El servicio se ofrece sin garantía de un resultado concreto. Los cambios importantes se mostrarán con una nueva fecha. Se mantienen los derechos obligatorios del consumidor."])
            ]
        }
        return [
            .init(id: "acceptance", title: "1. Acceptance", paragraphs: ["By using NinetyLens, you accept these Terms of Use. If you do not agree, do not use the app. You may delete your anonymous account from the profile screen at any time."]),
            .init(id: "service", title: "2. Service", paragraphs: ["NinetyLens provides match schedules, favorites, analysis history, and AI-assisted probability analysis. Features, league coverage, credit costs, and free allowances may change over time."]),
            .init(id: "disclaimer", title: "3. Predictions and betting disclaimer", paragraphs: ["All analyses are probabilistic information for informational and entertainment purposes only. They are not guaranteed outcomes, financial advice, or betting advice. Data may be incomplete, delayed, or incorrect. You remain responsible for your decisions and losses."]),
            .init(id: "account", title: "4. Account and free use", paragraphs: ["The app creates an anonymous Firebase account by default. You are responsible for device and account security. The current free plan provides one unique analysis view per month; an existing analysis for the same match may be reused without generating it again."]),
            .init(id: "purchases", title: "5. Credits and purchases", paragraphs: ["Credits are consumable digital goods offered through Apple’s in-app purchase system. Purchased credits do not expire. A refund confirmed by Apple may remove the corresponding unused credits. Apple processes payments and refunds."]),
            .init(id: "acceptable", title: "6. Acceptable use", paragraphs: ["You may not reverse engineer the service, send automated bulk requests, bypass quota or security controls, redistribute API data without authorization, or use the service unlawfully. Access may be limited in response to abuse."]),
            .init(id: "thirdparty", title: "7. Third-party services", paragraphs: ["Match data is supplied by football-data.org, infrastructure by Firebase/Google Cloud, AI analysis by Google Gemini, and one-time credit purchase validation by RevenueCat. Outages, delays, or data changes in those services may be outside NinetyLens’s control."]),
            .init(id: "ip", title: "8. Intellectual property", paragraphs: ["The NinetyLens name, design, and application code belong to their respective rights holders. Team, league, and provider names may be trademarks of their owners. You receive a limited, personal, non-transferable right to use the app."]),
            .init(id: "availability", title: "9. Availability and liability", paragraphs: ["The service is provided as is, without a guarantee of uninterrupted or error-free operation or fitness for a particular outcome. Subject to mandatory law, NinetyLens is not responsible for indirect damages or losses arising from app use."]),
            .init(id: "changes", title: "10. Changes and termination", paragraphs: ["The service and these terms may be updated. Material changes will appear with a new effective date. Access may be suspended for violations; you may stop using the service by deleting your account. Mandatory consumer rights in your location remain unaffected."])
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
    var onWalletUpdated: (CreditWallet) -> Void = { _ in }
    var onPurchaseCompleted: (CreditWallet) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var packages: [CreditPackage] = []
    @State private var selectedPackageID: String?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var message: String?
    @State private var syncedWallet: CreditWallet?

    private var displayedWallet: CreditWallet { syncedWallet ?? wallet }

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
                            Text(appText("Mevcut bakiye: \(displayedWallet.balance) kredi", "Current balance: \(creditText(displayedWallet.balance))"))
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
                                                Text(appText("Tek seferlik kredi paketi", "One-time credit pack"))
                                                    .font(.caption2)
                                                    .foregroundStyle(NeonTheme.secondaryText)
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

                        Text(appText("Bir maç analizi şu anda \(displayedWallet.analysisCreditCost) kredi.", "A match analysis currently costs \(creditText(displayedWallet.analysisCreditCost))."))
                            .font(.footnote).foregroundStyle(NeonTheme.secondaryText).frame(maxWidth: .infinity).padding(14).glassCard(radius: 16)

                        if let message { Text(message).font(.footnote).foregroundStyle(NeonTheme.cyan).multilineTextAlignment(.center) }

                        Button { purchase() } label: {
                            Group {
                                if isPurchasing { ProgressView().tint(.white) }
                                else { Text(appText("Seçili kredi paketini satın al", "Purchase selected credit pack")) }
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(NeonTheme.gradient, in: Capsule())
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
                if result == .purchased {
                    message = appText("Satın alma doğrulandı. Kredi bakiyesi sunucudan eşitleniyor.", "Purchase verified. Your credit balance is syncing from the server.")
                    await synchronizePurchasedCredits(previousBalance: displayedWallet.balance)
                } else {
                    message = appText("Satın alma iptal edildi.", "Purchase cancelled.")
                }
            } catch {
                message = appText("Satın alma tamamlanamadı. Lütfen tekrar dene.", "The purchase could not be completed. Please try again.")
            }
            isPurchasing = false
        }
    }

    private func synchronizePurchasedCredits(previousBalance: Int) async {
        for attempt in 0..<30 {
            if attempt > 0 {
                try? await Task.sleep(for: attempt < 10 ? .seconds(1) : .seconds(2))
            }
            guard !Task.isCancelled else { return }
            guard let updatedWallet = try? await compositionRoot.creditWallet() else { continue }
            syncedWallet = updatedWallet
            onWalletUpdated(updatedWallet)
            if updatedWallet.balance > previousBalance {
                message = appText(
                    "Kredilerin hesabına eklendi. Yeni bakiye: \(updatedWallet.balance)",
                    "Your credits were added. New balance: \(creditText(updatedWallet.balance))"
                )
                onPurchaseCompleted(updatedWallet)
                return
            }
        }
        message = appText(
            "Satın alma tamamlandı ancak webhook henüz ulaşmadı. Bakiye uygulama yeniden açıldığında otomatik yenilenecek.",
            "Purchase completed, but the webhook has not arrived yet. Your balance will refresh automatically when the app is reopened."
        )
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
            if !compact { Text("NinetyLens").font(.headline.bold()).foregroundStyle(.white) }
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
