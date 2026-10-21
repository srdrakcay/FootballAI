#if os(iOS)
import CoreDomain
import SwiftUI

enum DetailTab: CaseIterable, Hashable { case analysis, form, headToHead, standings }

struct MatchDetailScreen: View {
    let fixture: Fixture
    @Environment(SessionStore.self) var session
    @State var tab: DetailTab = .analysis
    @State var insights: FixtureInsights?
    @State var insightsFailed = false
    @State var readyAnalysis: UnlockedAnalysis?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MatchHero(fixture: fixture, standings: insights?.standings)
                tabs
                switch tab {
                case .analysis:
                    AnalysisPanel(fixture: fixture, ready: $readyAnalysis)
                    if let form = insights?.recentForm { FormSummaryCard(fixture: fixture, form: form, compact: true) }
                case .form:
                    insightContent { insights in
                        if let form = insights.recentForm { FormSummaryCard(fixture: fixture, form: form, compact: false) } else { unavailable }
                    }
                case .headToHead:
                    insightContent { insights in
                        if insights.headToHead.isEmpty { unavailable } else { HeadToHeadCard(matches: insights.headToHead) }
                    }
                case .standings:
                    insightContent { insights in
                        if let standings = insights.standings { StandingsCard(fixture: fixture, standings: standings) } else { unavailable }
                    }
                }
            }
            .padding(.horizontal, Pitch.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .pitchScreen()
        .navigationTitle(Text(Competitions.knownName(fixture.competition)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let readyAnalysis {
                    ShareLink(item: shareText(readyAnalysis)) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel(Text("detail.share", bundle: .module))
                }
                Button { session.toggleFavorite(fixture) } label: {
                    Image(systemName: session.isFavorite(fixture) ? "star.fill" : "star")
                        .foregroundStyle(session.isFavorite(fixture) ? Pitch.accent : Pitch.text)
                }
                .accessibilityLabel(session.isFavorite(fixture) ? Text("matches.unfavorite", bundle: .module) : Text("matches.favorite", bundle: .module))
                .sensoryFeedback(.impact(weight: .light), trigger: session.isFavorite(fixture))
            }
        }
        .task { await loadInsights() }
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(DetailTab.allCases, id: \.self) { item in
                Button { withAnimation(.snappy) { tab = item } } label: {
                    item.title
                        .font(.footnote.weight(tab == item ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(tab == item ? Pitch.onAccent : Pitch.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(tab == item ? Pitch.text : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Pitch.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Pitch.hairline) }
    }

    @ViewBuilder
    private func insightContent<Content: View>(@ViewBuilder _ content: (FixtureInsights) -> Content) -> some View {
        if let insights {
            content(insights)
        } else if insightsFailed {
            EmptyStateView(
                symbol: "chart.bar.xaxis",
                title: Text("insights.error.title", bundle: .module),
                message: Text("insights.error.message", bundle: .module),
                actionTitle: Text("common.retry", bundle: .module),
                action: { Task { await loadInsights() } }
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(width: 120); SkeletonBlock(height: 26); SkeletonBlock(height: 26)
            }
            .pitchCard()
        }
    }

    private var unavailable: some View {
        EmptyStateView(symbol: "chart.bar.xaxis", title: Text("insights.unavailable.title", bundle: .module), message: Text("insights.unavailable.message", bundle: .module))
    }

    private func loadInsights() async {
        insightsFailed = false
        do { insights = try await session.insights(for: fixture.key) }
        catch { insightsFailed = true }
    }

    private func shareText(_ value: UnlockedAnalysis) -> String {
        let result = value.analysis.markets.matchResult
        return "\(fixture.homeTeam.name) – \(fixture.awayTeam.name)\n\(value.personal.headline)\n\(fixture.homeTeam.name) \(result.homePct)% · \(result.drawPct)% · \(fixture.awayTeam.name) \(result.awayPct)%\nNinetyLens"
    }
}

extension DetailTab {
    var title: Text {
        switch self {
        case .analysis: Text("detail.tab.analysis", bundle: .module)
        case .form: Text("detail.tab.form", bundle: .module)
        case .headToHead: Text("detail.tab.h2h", bundle: .module)
        case .standings: Text("detail.tab.standings", bundle: .module)
        }
    }
}

// MARK: - Hero

struct MatchHero: View {
    let fixture: Fixture
    let standings: TeamStandingPair?

    var body: some View {
        HStack(alignment: .top) {
            team(fixture.homeTeam.name, side: .home, position: standings?.home.position)
            VStack(spacing: 4) {
                Text(fixture.kickoffAt, format: .dateTime.hour().minute()).font(.display(40))
                Group {
                    if fixture.kickoffAt > .now, fixture.status.acceptsNewAnalysis {
                        Text(fixture.kickoffAt, style: .relative)
                    } else {
                        Text(fixture.kickoffAt, format: .dateTime.day().month(.abbreviated))
                    }
                }
                .font(.caption).foregroundStyle(Pitch.textMuted).multilineTextAlignment(.center)
            }
            .frame(minWidth: 100)
            .padding(.top, 10)
            team(fixture.awayTeam.name, side: .away, position: standings?.away.position)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func team(_ name: String, side: TeamBadge.Side, position: Int?) -> some View {
        VStack(spacing: 8) {
            TeamBadge(name: name, side: side, size: 60)
            Text(name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
            if let position {
                Text("detail.position \(position)", bundle: .module).font(.caption).foregroundStyle(Pitch.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Analysis panel

struct AnalysisPanel: View {
    enum Phase: Equatable {
        case checking, locked, unlocking, ready(UnlockedAnalysis), ineligible
        case failed(Failure)
    }
    enum Failure: Equatable { case offline, inProgress, generic }

    let fixture: Fixture
    @Binding var ready: UnlockedAnalysis?
    @Environment(SessionStore.self) var session
    @State var phase: Phase = .checking
    @State var step = 0
    @State var showsPaywall = false
    @State var unlockAfterPurchase = false
    @State var successTrigger = 0

    private var eligibleForNew: Bool {
        fixture.status.acceptsNewAnalysis && fixture.kickoffAt > .now.addingTimeInterval(5 * 60)
    }

    var body: some View {
        Group {
            switch phase {
            case .checking: checking
            case .locked: locked
            case .unlocking: unlocking
            case .ready(let value): AnalysisResultView(fixture: fixture, value: value, profile: session.profile)
            case .ineligible: ineligible
            case .failed(let failure): failed(failure)
            }
        }
        .animation(.snappy, value: phase)
        .sensoryFeedback(.success, trigger: successTrigger)
        .task(id: fixture.key) { await resolve() }
        .sheet(isPresented: $showsPaywall, onDismiss: {
            if unlockAfterPurchase, session.wallet?.canAffordAnalysis == true { unlock() }
            unlockAfterPurchase = false
        }) {
            PaywallView(context: fixture) { unlockAfterPurchase = true }
        }
    }

    private func resolve() async {
        if let cached = session.cachedAnalysis(for: fixture.key) { show(cached, celebrate: false); return }
        if session.isKnownLocked(fixture.key) { phase = eligibleForNew ? .locked : .ineligible; return }
        do {
            switch try await session.open(fixture) {
            case .unlocked(let value): show(value, celebrate: false)
            case .locked: phase = eligibleForNew ? .locked : .ineligible
            }
        } catch {
            phase = eligibleForNew ? .locked : .ineligible
        }
    }

    private func show(_ value: UnlockedAnalysis, celebrate: Bool) {
        phase = .ready(value)
        ready = value
        if celebrate { successTrigger += 1 }
    }

    private func unlock() {
        guard let wallet = session.wallet, wallet.canAffordAnalysis else { showsPaywall = true; return }
        phase = .unlocking
        step = 0
        Task {
            let ticker = Task {
                for next in 1...2 {
                    try await Task.sleep(for: .seconds(2.6))
                    withAnimation(.snappy) { step = next }
                }
            }
            defer { ticker.cancel() }
            do {
                show(try await session.unlock(fixture), celebrate: true)
            } catch DomainError.insufficientCredits {
                phase = .locked
                showsPaywall = true
            } catch DomainError.networkOffline {
                phase = .failed(.offline)
            } catch DomainError.generationInProgress {
                phase = .failed(.inProgress)
            } catch DomainError.fixtureIneligible {
                phase = .ineligible
            } catch {
                phase = .failed(.generic)
            }
        }
    }

    // MARK: States

    private var checking: some View {
        VStack(alignment: .leading, spacing: 14) {
            SkeletonBlock(width: 160, height: 18)
            SkeletonBlock(height: 34)
            HStack(spacing: 8) { SkeletonBlock(height: 52); SkeletonBlock(height: 52) }
        }
        .pitchCard()
    }

    private var locked: some View {
        let cost = session.wallet?.analysisCreditCost ?? 1
        let canAfford = session.wallet?.canAffordAnalysis ?? true
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("analysis.locked.title", bundle: .module).font(.headline)
                Spacer()
                Label { Text("analysis.locked.badge", bundle: .module) } icon: { Image(systemName: "lock.fill") }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Pitch.textSecondary)
                    .padding(.horizontal, 10).frame(minHeight: 26)
                    .background(Pitch.surfaceRaised, in: Capsule())
            }
            VStack(spacing: 8) {
                OutcomeBar(home: 44, draw: 28, away: 28, height: 30).opacity(0.3)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 10).fill(Pitch.surfaceRaised).frame(height: 44) }
                }
                .opacity(0.4)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                includes(Text("analysis.locked.include1", bundle: .module))
                includes(Text("analysis.locked.include2", bundle: .module))
                includes(personalPromise)
            }
            Button { unlock() } label: {
                Label { Text("analysis.unlock \(cost)", bundle: .module) } icon: { Image(systemName: "bolt.fill") }
            }
            .buttonStyle(PrimaryButtonStyle())
            Group {
                if let wallet = session.wallet {
                    canAfford
                        ? Text("analysis.locked.balance \(wallet.available)", bundle: .module)
                        : Text("analysis.locked.no_credits", bundle: .module)
                } else {
                    Text("analysis.locked.once", bundle: .module)
                }
            }
            .font(.caption).foregroundStyle(canAfford ? Pitch.textMuted : Pitch.warning)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
        .pitchCard(padding: 18)
    }

    private var personalPromise: Text {
        let style = session.profile.style.title
        if let team = session.profile.favoriteTeam,
           [fixture.homeTeam.id.rawValue, fixture.awayTeam.id.rawValue].contains(team.id) {
            return Text("analysis.locked.include3.team \(team.name) \(style)", bundle: .module)
        }
        return Text("analysis.locked.include3 \(style)", bundle: .module)
    }

    private func includes(_ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(Pitch.accent)
            text.font(.subheadline).foregroundStyle(Pitch.textSecondary)
        }
    }

    private var unlocking: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("analysis.unlocking.title", bundle: .module).font(.headline)
            VStack(alignment: .leading, spacing: 14) {
                progressRow(0, Text("analysis.unlocking.step1", bundle: .module))
                progressRow(1, Text("analysis.unlocking.step2", bundle: .module))
                progressRow(2, Text("analysis.unlocking.step3", bundle: .module))
            }
            Text("analysis.unlocking.note", bundle: .module).font(.caption).foregroundStyle(Pitch.textMuted)
        }
        .pitchCard(padding: 18)
    }

    private func progressRow(_ index: Int, _ text: Text) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if index < step {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Pitch.accent)
                } else if index == step {
                    ProgressView().controlSize(.small).tint(Pitch.accent)
                } else {
                    Circle().strokeBorder(Pitch.line, lineWidth: 2)
                }
            }
            .frame(width: 22, height: 22)
            text.font(.subheadline).foregroundStyle(index <= step ? Pitch.text : Pitch.textMuted)
        }
    }

    private var ineligible: some View {
        EmptyStateView(symbol: "clock", title: Text("analysis.ineligible.title", bundle: .module), message: Text("analysis.ineligible.message", bundle: .module))
    }

    private func failed(_ failure: Failure) -> some View {
        let message: Text = switch failure {
        case .offline: Text("analysis.error.offline", bundle: .module)
        case .inProgress: Text("analysis.error.in_progress", bundle: .module)
        case .generic: Text("analysis.error.generic", bundle: .module)
        }
        return EmptyStateView(
            symbol: failure == .offline ? "wifi.slash" : "exclamationmark.triangle",
            title: Text("analysis.error.title", bundle: .module),
            message: message,
            actionTitle: Text("common.retry", bundle: .module),
            action: { unlock() }
        )
    }
}
#endif
