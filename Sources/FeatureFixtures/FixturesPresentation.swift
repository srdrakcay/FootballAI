import CoreDomain
import CoreLocalization
import Foundation
import SwiftUI

@MainActor
public final class FixtureListViewModel: ObservableObject {
    public enum State: Equatable { case idle, loading, empty, loaded([Fixture]), failed }
    @Published public private(set) var state: State = .idle
    private let observeFixtures: any ObserveUpcomingFixturesUseCase
    private var task: Task<Void, Never>?

    public init(observeFixtures: any ObserveUpcomingFixturesUseCase) { self.observeFixtures = observeFixtures }
    deinit { task?.cancel() }
    public func load(day: Date = .now, calendar: Calendar = .current) {
        task?.cancel(); state = .loading
        let from = calendar.startOfDay(for: day)
        guard let through = calendar.date(byAdding: .day, value: 1, to: from)?.addingTimeInterval(-0.001) else {
            state = .failed
            return
        }
        let filter = FixtureFilter(from: from, through: through)
        task = Task { [weak self, observeFixtures] in
            do {
                for try await fixtures in observeFixtures(filter: filter) {
                    guard !Task.isCancelled else { return }
                    self?.state = fixtures.isEmpty ? .empty : .loaded(fixtures)
                }
            } catch { if !Task.isCancelled { self?.state = .failed } }
        }
    }
}

public struct FixtureListView<Destination: View>: View {
    @StateObject private var model: FixtureListViewModel
    private let destination: (Fixture) -> Destination
    public init(viewModel: @autoclosure @escaping () -> FixtureListViewModel, @ViewBuilder destination: @escaping (Fixture) -> Destination) {
        _model = StateObject(wrappedValue: viewModel()); self.destination = destination
    }
    public var body: some View {
        Group {
            switch model.state {
            case .idle, .loading: ProgressView()
            case .empty: ContentUnavailableView(L10n.text("fixtures.empty"), systemImage: "sportscourt")
            case .failed:
                ContentUnavailableView { Label(L10n.text("analysis.failure.retry"), systemImage: "exclamationmark.triangle") } actions: { Button(L10n.text("general.retry")) { model.load() } }
            case .loaded(let fixtures):
                List(fixtures) { fixture in
                    NavigationLink(destination: destination(fixture)) {
                        VStack(alignment: .leading) {
                            Text("\(fixture.homeTeam.name) – \(fixture.awayTeam.name)").font(.headline)
                            Text(fixture.kickoffAt, style: .date).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.text("fixtures.title"))
        .task { if case .idle = model.state { model.load() } }
    }
}

public struct FixtureDetailView<AnalysisContent: View>: View {
    public let fixture: Fixture
    private let analysisContent: () -> AnalysisContent
    public init(fixture: Fixture, @ViewBuilder analysisContent: @escaping () -> AnalysisContent) { self.fixture = fixture; self.analysisContent = analysisContent }
    public var body: some View {
        List {
            Section(fixture.competition.name) {
                LabeledContent(L10n.text("match.home"), value: fixture.homeTeam.name)
                LabeledContent(L10n.text("match.away"), value: fixture.awayTeam.name)
                LabeledContent(L10n.text("match.kickoff")) { Text(fixture.kickoffAt, style: .date) }
            }
            Section(L10n.text("analysis.title")) { analysisContent() }
        }
        .navigationTitle("\(fixture.homeTeam.name) – \(fixture.awayTeam.name)")
    }
}
