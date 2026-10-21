#if os(iOS)
import CoreDomain
import SwiftUI

enum MatchFilter: Hashable {
    case all, favorites, analyzed, competition(String)
}

struct MatchesScreen: View {
    @Environment(SessionStore.self) var session
    @Environment(MatchesStore.self) var matches
    @State var filter: MatchFilter = .all
    @State var showsCalendar = false
    @State var showsPaywall = false
    @State var calendarDate = Date.now

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18, pinnedViews: []) {
                header
                dayStrip
                filterBar
                content
            }
            .padding(.horizontal, Pitch.screenPadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await matches.refreshSelected()
            await session.refreshLibrary()
        }
        .pitchScreen()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Fixture.self) { MatchDetailScreen(fixture: $0) }
        .sheet(isPresented: $showsCalendar) { calendarSheet }
        .sheet(isPresented: $showsPaywall) { PaywallView(context: nil) }
        .onChange(of: matches.selectedDay) { _, _ in
            if case .competition = filter { filter = .all }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(matches.selectedDay, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.footnote.weight(.medium)).foregroundStyle(Pitch.textMuted)
                Text("matches.title", bundle: .module).font(.display(38))
            }
            Spacer()
            Button { showsPaywall = true } label: { CreditPill(available: session.wallet?.available) }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("a11y.credits \(session.wallet?.available ?? 0)", bundle: .module))
        }
        .padding(.top, 8)
    }

    private var dayStrip: some View {
        HStack(spacing: 8) {
            ForEach(matches.stripDays.prefix(5), id: \.self) { day in
                let selected = Calendar.current.isDate(day, inSameDayAs: matches.selectedDay)
                Button { matches.select(day) } label: {
                    VStack(spacing: 2) {
                        Text(dayLabel(day)).font(.caption2.weight(selected ? .semibold : .medium))
                        Text(day, format: .dateTime.day()).font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(selected ? Pitch.onAccent : Pitch.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(selected ? Pitch.accent : Pitch.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(selected ? Pitch.accent : Pitch.line) }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Button { calendarDate = matches.selectedDay; showsCalendar = true } label: {
                Image(systemName: "calendar").font(.headline)
                    .frame(width: 48, height: 56)
                    .background(Pitch.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Pitch.line) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("matches.calendar", bundle: .module))
        }
        .sensoryFeedback(.selection, trigger: matches.selectedDay)
    }

    private func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "day.today", bundle: .module) }
        if calendar.isDateInTomorrow(day) { return String(localized: "day.tomorrow", bundle: .module) }
        if calendar.isDateInYesterday(day) { return String(localized: "day.yesterday", bundle: .module) }
        return day.formatted(.dateTime.weekday(.abbreviated))
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(.all, Text("filter.all \(dayFixtures.count)", bundle: .module))
                chip(.favorites, Text("filter.favorites", bundle: .module))
                chip(.analyzed, Text("filter.analyzed", bundle: .module))
                ForEach(dayCompetitions, id: \.id) { competition in
                    chip(.competition(competition.id.rawValue), Text(Competitions.knownName(competition)))
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ value: MatchFilter, _ title: Text) -> some View {
        Button { withAnimation(.snappy) { filter = value } } label: { title }
            .buttonStyle(ChipButtonStyle(selected: filter == value, strong: true))
            .accessibilityAddTraits(filter == value ? .isSelected : [])
    }

    // MARK: Content

    private var dayFixtures: [Fixture] {
        if case .loaded(let list, _) = matches.selectedState { return list }
        return []
    }

    private var dayCompetitions: [Competition] {
        var seen = Set<CompetitionID>()
        return orderedCompetitions(dayFixtures).filter { seen.insert($0.id).inserted }
    }

    private var visibleFixtures: [Fixture] {
        switch filter {
        case .all: dayFixtures
        case .favorites:
            dayFixtures.filter { session.isFavorite($0) || isFavoriteTeam($0) }
        case .analyzed: dayFixtures.filter { session.historyItem(for: $0.key) != nil }
        case .competition(let id): dayFixtures.filter { $0.competition.id.rawValue == id }
        }
    }

    @ViewBuilder private var content: some View {
        switch matches.selectedState {
        case .loading:
            VStack(spacing: 12) { ForEach(0..<4, id: \.self) { _ in skeletonRow } }
        case .failed:
            EmptyStateView(
                symbol: "wifi.exclamationmark",
                title: Text("matches.error.title", bundle: .module),
                message: Text("matches.error.message", bundle: .module),
                actionTitle: Text("common.retry", bundle: .module),
                action: { matches.load(matches.selectedDay, force: true) }
            )
        case .loaded:
            if let spotlight = spotlightFixture, filter == .all {
                NavigationLink(value: spotlight) { SpotlightCard(fixture: spotlight) }
                    .buttonStyle(.plain)
            }
            if visibleFixtures.isEmpty {
                emptyState
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(Competitions.knownName(group.competition)).font(.footnote.weight(.semibold)).foregroundStyle(Pitch.textSecondary)
                            Spacer()
                            Text("matches.count \(group.fixtures.count)", bundle: .module).font(.caption).foregroundStyle(Pitch.textMuted)
                        }
                        .padding(.horizontal, 2)
                        VStack(spacing: 0) {
                            ForEach(group.fixtures) { fixture in
                                NavigationLink(value: fixture) {
                                    FixtureRow(fixture: fixture, history: session.historyItem(for: fixture.key), creditCost: session.wallet?.analysisCreditCost ?? 1)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { favoriteMenu(fixture) }
                                if fixture.key != group.fixtures.last?.key { Divider().overlay(Pitch.hairline) }
                            }
                        }
                        .background(Pitch.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Pitch.hairline) }
                    }
                }
            }
        }
    }

    @ViewBuilder private func favoriteMenu(_ fixture: Fixture) -> some View {
        Button { session.toggleFavorite(fixture) } label: {
            session.isFavorite(fixture)
                ? Label { Text("matches.unfavorite", bundle: .module) } icon: { Image(systemName: "star.slash") }
                : Label { Text("matches.favorite", bundle: .module) } icon: { Image(systemName: "star") }
        }
    }

    private var emptyState: some View {
        switch filter {
        case .favorites:
            EmptyStateView(symbol: "star", title: Text("matches.empty.favorites.title", bundle: .module), message: Text("matches.empty.favorites.message", bundle: .module))
        case .analyzed:
            EmptyStateView(symbol: "chart.bar", title: Text("matches.empty.analyzed.title", bundle: .module), message: Text("matches.empty.analyzed.message", bundle: .module))
        default:
            EmptyStateView(symbol: "calendar", title: Text("matches.empty.title", bundle: .module), message: Text("matches.empty.message", bundle: .module))
        }
    }

    private var skeletonRow: some View {
        HStack(spacing: 14) {
            SkeletonBlock(height: 18, width: 44)
            VStack(alignment: .leading, spacing: 8) { SkeletonBlock(width: 140); SkeletonBlock(width: 110) }
            Spacer()
            SkeletonBlock(height: 28, width: 56)
        }
        .pitchCard(padding: 14)
    }

    /// The reader's team playing today (and not yet kicked off) gets a highlighted card.
    private var spotlightFixture: Fixture? {
        dayFixtures.first { isFavoriteTeam($0) && $0.kickoffAt > .now }
    }

    private func isFavoriteTeam(_ fixture: Fixture) -> Bool {
        guard let id = session.profile.favoriteTeam?.id else { return false }
        return fixture.homeTeam.id.rawValue == id || fixture.awayTeam.id.rawValue == id
    }

    private var groups: [FixtureGroup] {
        let hidden = filter == .all ? spotlightFixture?.key : nil
        let grouped = Dictionary(grouping: visibleFixtures.filter { $0.key != hidden }) { $0.competition.id }
        var result: [FixtureGroup] = []
        for competition in orderedCompetitions(visibleFixtures) where !result.contains(where: { $0.id == competition.id }) {
            guard let fixtures = grouped[competition.id], !fixtures.isEmpty else { continue }
            result.append(FixtureGroup(competition: competition, fixtures: fixtures.sorted { $0.kickoffAt < $1.kickoffAt }))
        }
        return result
    }

    /// The reader's leagues first, then in the provider's usual order.
    private func orderedCompetitions(_ fixtures: [Fixture]) -> [Competition] {
        let preferred = session.profile.competitionIds
        return fixtures.map(\.competition).sorted { first, second in
            let a = preferred.firstIndex(of: first.id.rawValue) ?? (100 + (Competitions.all.firstIndex(of: first.id.rawValue) ?? 50))
            let b = preferred.firstIndex(of: second.id.rawValue) ?? (100 + (Competitions.all.firstIndex(of: second.id.rawValue) ?? 50))
            return a == b ? first.name < second.name : a < b
        }
    }

    private var calendarSheet: some View {
        NavigationStack {
            DatePicker(selection: $calendarDate, displayedComponents: .date) { Text("matches.calendar", bundle: .module) }
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle(Text("matches.calendar", bundle: .module))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { matches.select(calendarDate); showsCalendar = false } label: { Text("common.done", bundle: .module).bold() }
                    }
                }
                .pitchScreen()
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Pitch.background)
    }
}

struct FixtureGroup: Identifiable {
    let competition: Competition
    let fixtures: [Fixture]
    var id: CompetitionID { competition.id }
}

extension Competitions {
    static func knownName(_ competition: Competition) -> String {
        all.contains(competition.id.rawValue) ? name(competition.id.rawValue) : competition.name
    }
}

// MARK: - Rows

struct FixtureRow: View {
    let fixture: Fixture
    let history: AnalysisHistoryItem?
    let creditCost: Int

    var body: some View {
        HStack(spacing: 14) {
            kickoff.frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(fixture.homeTeam.name).lineLimit(1)
                Text(fixture.awayTeam.name).lineLimit(1)
            }
            .font(.subheadline)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var kickoff: some View {
        switch fixture.status {
        case .inProgress:
            Text("status.live", bundle: .module).font(.caption.weight(.bold)).foregroundStyle(Pitch.accent)
        case .finished, .awarded:
            Text("status.finished", bundle: .module).font(.caption.weight(.semibold)).foregroundStyle(Pitch.textMuted)
        case .postponed, .cancelled, .suspended:
            Text("status.postponed", bundle: .module).font(.caption.weight(.semibold)).foregroundStyle(Pitch.warning)
        default:
            Text(fixture.kickoffAt, format: .dateTime.hour().minute())
                .font(.display(18, weight: .semibold)).foregroundStyle(Pitch.textSecondary)
        }
    }

    @ViewBuilder private var trailing: some View {
        if let history, history.hasFullResult,
           let home = history.homeWinProbability, let draw = history.drawProbability, let away = history.awayWinProbability {
            VStack(alignment: .trailing, spacing: 5) {
                OutcomeBar(home: home, draw: draw, away: away, height: 6).frame(width: 88)
                Text("matches.row.analyzed", bundle: .module).font(.caption2).foregroundStyle(Pitch.textMuted)
            }
        } else if history != nil {
            Label { Text("matches.row.analyzed", bundle: .module) } icon: { Image(systemName: "checkmark.circle.fill") }
                .font(.caption.weight(.semibold)).foregroundStyle(Pitch.accent)
        } else if fixture.status.acceptsNewAnalysis, fixture.kickoffAt > .now.addingTimeInterval(300) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(Pitch.accent)
                Text(creditCost, format: .number).font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(Pitch.surfaceRaised, in: Capsule())
            .overlay { Capsule().strokeBorder(Pitch.line) }
            .accessibilityLabel(Text("a11y.analysis_cost \(creditCost)", bundle: .module))
        }
    }
}

struct SpotlightCard: View {
    let fixture: Fixture
    @Environment(SessionStore.self) var session

    var body: some View {
        let unlocked = session.historyItem(for: fixture.key) != nil
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: Text("matches.spotlight", bundle: .module))
                Spacer()
                Text(Competitions.knownName(fixture.competition)).font(.caption).foregroundStyle(Pitch.textMuted)
            }
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    TeamBadge(name: fixture.homeTeam.name, side: .home)
                    Text(fixture.homeTeam.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(fixture.kickoffAt, format: .dateTime.hour().minute()).font(.display(24))
                HStack(spacing: 10) {
                    Text(fixture.awayTeam.name).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.trailing)
                    TeamBadge(name: fixture.awayTeam.name, side: .away)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Divider().overlay(Pitch.line)
            HStack {
                (unlocked ? Text("matches.spotlight.ready", bundle: .module) : Text("matches.spotlight.available", bundle: .module))
                    .font(.footnote).foregroundStyle(Pitch.textMuted)
                Spacer()
                (unlocked ? Text("matches.spotlight.view", bundle: .module) : Text("matches.spotlight.open", bundle: .module))
                    .font(.footnote.weight(.semibold)).foregroundStyle(Pitch.accent)
            }
        }
        .pitchCard(highlighted: true)
    }
}
#endif
