#if os(iOS)
import CoreDomain
import SwiftUI

struct HistoryScreen: View {
    enum Segment: Hashable { case upcoming, past }
    @Environment(SessionStore.self) var session
    @State var segment: Segment = .upcoming

    private var items: [AnalysisHistoryItem] {
        let now = Date.now
        return switch segment {
        case .upcoming: session.history.filter { $0.kickoffAt > now }.sorted { $0.kickoffAt < $1.kickoffAt }
        case .past: session.history.filter { $0.kickoffAt <= now }.sorted { $0.kickoffAt > $1.kickoffAt }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("history.title", bundle: .module).font(.display(38)).padding(.top, 8)
                Picker(selection: $segment) {
                    Text("history.upcoming", bundle: .module).tag(Segment.upcoming)
                    Text("history.past", bundle: .module).tag(Segment.past)
                } label: { EmptyView() }
                .pickerStyle(.segmented)

                if !session.historyLoaded {
                    ForEach(0..<3, id: \.self) { _ in SkeletonBlock(height: 92) }
                } else if items.isEmpty {
                    EmptyStateView(
                        symbol: "chart.bar.xaxis",
                        title: segment == .upcoming ? Text("history.empty.upcoming.title", bundle: .module) : Text("history.empty.past.title", bundle: .module),
                        message: Text("history.empty.message", bundle: .module)
                    )
                } else {
                    ForEach(items) { item in
                        NavigationLink(value: item.fixture) { HistoryCard(item: item) }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Pitch.screenPadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await session.refreshLibrary() }
        .pitchScreen()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Fixture.self) { MatchDetailScreen(fixture: $0) }
    }
}

struct HistoryCard: View {
    let item: AnalysisHistoryItem
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.competitionName).font(.caption).foregroundStyle(Pitch.textMuted).lineLimit(1)
                Spacer()
                Text(item.kickoffAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(.caption.weight(.semibold)).foregroundStyle(Pitch.textSecondary)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.homeTeamName).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(item.awayTeamName).font(.subheadline.weight(.semibold)).foregroundStyle(Pitch.textSecondary).lineLimit(1)
                }
                Spacer()
                if let home = item.homeWinProbability {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(percent(home)).font(.display(24)).foregroundStyle(Pitch.homeText)
                        Text("history.home_win", bundle: .module).font(.caption2).foregroundStyle(Pitch.textMuted)
                    }
                }
            }
            if item.hasFullResult, let home = item.homeWinProbability, let draw = item.drawProbability, let away = item.awayWinProbability {
                OutcomeBar(home: home, draw: draw, away: away, height: 6)
            }
        }
        .pitchCard()
        .accessibilityElement(children: .combine)
    }
}

extension AnalysisHistoryItem {
    /// Enough of a fixture to open its detail screen from history.
    var fixture: Fixture {
        Fixture(
            key: fixtureKey,
            version: 1,
            competition: Competition(id: .init(rawValue: competitionName), name: competitionName),
            homeTeam: Team(id: .init(rawValue: homeTeamName), name: homeTeamName),
            awayTeam: Team(id: .init(rawValue: awayTeamName), name: awayTeamName),
            kickoffAt: kickoffAt,
            status: kickoffAt > .now ? .scheduled : .finished,
            latestSnapshotID: nil
        )
    }
}
#endif
