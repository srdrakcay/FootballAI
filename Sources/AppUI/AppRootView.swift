#if os(iOS)
import CoreDomain
import FootballAIAppCore
import SwiftUI

/// Entry point of the redesigned app. Returning users land on the match list immediately;
/// the session (sign-in, wallet, profile) loads in the background.
public struct AppRootView: View {
    @State var session: SessionStore
    @State var matches: MatchesStore
    @AppStorage("footballai.onboarding.completed.v2") var completedOnboarding = false

    public init(root: AppCompositionRoot) {
        _session = State(initialValue: SessionStore(root: root))
        _matches = State(initialValue: MatchesStore(root: root))
    }

    public var body: some View {
        Group {
            if completedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                AIProfileOnboardingView { profile in
                    withAnimation(.easeInOut(duration: 0.35)) { completedOnboarding = true }
                    Task { try? await session.saveProfile(profile) }
                }
                .transition(.opacity)
            }
        }
        .environment(session)
        .environment(matches)
        .preferredColorScheme(.dark)
        .tint(Pitch.accent)
        .task {
            matches.select(.now)
            await session.start()
        }
    }
}

enum AppTab: Hashable { case matches, analyses, profile }

struct MainTabView: View {
    @State var selection: AppTab = .matches

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { MatchesScreen() }
                .tabItem { Label { Text("tab.matches", bundle: .module) } icon: { Image(systemName: "soccerball") } }
                .tag(AppTab.matches)
            NavigationStack { HistoryScreen() }
                .tabItem { Label { Text("tab.analyses", bundle: .module) } icon: { Image(systemName: "chart.bar.xaxis") } }
                .tag(AppTab.analyses)
            NavigationStack { ProfileScreen() }
                .tabItem { Label { Text("tab.profile", bundle: .module) } icon: { Image(systemName: "person.crop.circle") } }
                .tag(AppTab.profile)
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Pitch.tabBar)
            appearance.shadowColor = UIColor(Pitch.hairline)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
#endif
