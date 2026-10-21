#if os(iOS)
import CoreDomain
import FootballAIAppCore
import Foundation
import Observation

/// Day-by-day fixture cache. A day already seen opens instantly, the neighbouring days are
/// prefetched in the background, and a refresh never blanks a list that is already on screen.
@MainActor
@Observable
final class MatchesStore {
    enum DayState: Equatable {
        case loading
        case loaded([Fixture], refreshedAt: Date)
        case failed
    }

    private(set) var days: [Date: DayState] = [:]
    private(set) var selectedDay: Date
    private var tasks: [Date: Task<Void, Never>] = [:]
    private let root: AppCompositionRoot
    private let calendar: Calendar
    private let freshness: TimeInterval = 5 * 60

    init(root: AppCompositionRoot, calendar: Calendar = .current) {
        self.root = root
        self.calendar = calendar
        self.selectedDay = calendar.startOfDay(for: .now)
    }

    var selectedState: DayState { days[selectedDay] ?? .loading }

    func select(_ day: Date) {
        selectedDay = calendar.startOfDay(for: day)
        load(selectedDay)
        prefetchNeighbours()
    }

    func refreshSelected() async {
        load(selectedDay, force: true)
        await tasks[selectedDay]?.value
    }

    func load(_ day: Date, force: Bool = false) {
        let key = calendar.startOfDay(for: day)
        if tasks[key] != nil { return }
        if !force, case .loaded(_, let refreshedAt) = days[key], Date.now.timeIntervalSince(refreshedAt) < freshness { return }
        if days[key] == nil || days[key] == .failed { days[key] = .loading }

        let stream = root.fixtures(on: key, calendar: calendar)
        tasks[key] = Task { [weak self] in
            do {
                for try await fixtures in stream {
                    self?.days[key] = .loaded(fixtures, refreshedAt: .now)
                }
            } catch {
                guard let self else { return }
                if case .loaded = self.days[key] {} else { self.days[key] = .failed }
            }
            self?.tasks[key] = nil
        }
    }

    private func prefetchNeighbours() {
        for offset in [1, -1, 2] {
            if let day = calendar.date(byAdding: .day, value: offset, to: selectedDay) { load(day) }
        }
    }

    /// Today − 1 … today + 5: the strip the matches screen shows.
    var stripDays: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (-1...5).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
}
#endif
