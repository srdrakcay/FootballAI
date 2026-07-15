import CoreDomain
import CoreLocalization
import Foundation
import SwiftUI

@MainActor
public final class AnalysisViewModel: ObservableObject {
    public enum State: Equatable { case idle, requesting, progressing(AnalysisState), ready(Analysis), failed }
    @Published public private(set) var state: State = .idle
    private let fixtureKey: FixtureKey; private let locale: SupportedLocale
    private let requestAnalysis: any RequestAnalysisUseCase
    private let observeAnalysis: any ObserveAnalysisUseCase
    private let getAnalysis: any GetLocalizedAnalysisUseCase
    private var task: Task<Void, Never>?

    public init(fixtureKey: FixtureKey, locale: SupportedLocale, requestAnalysis: any RequestAnalysisUseCase, observeAnalysis: any ObserveAnalysisUseCase, getAnalysis: any GetLocalizedAnalysisUseCase) {
        self.fixtureKey = fixtureKey; self.locale = locale; self.requestAnalysis = requestAnalysis
        self.observeAnalysis = observeAnalysis; self.getAnalysis = getAnalysis
    }
    deinit { task?.cancel() }
    public func generate() {
        task?.cancel(); state = .requesting
        let command = RequestAnalysisCommand(fixtureKey: fixtureKey, requestedLocale: locale, clientRequestID: UUID(), acceptedDisclaimerVersion: "legal_v1")
        task = Task { [weak self, requestAnalysis, observeAnalysis, getAnalysis] in
            do {
                let request = try await requestAnalysis(command)
                if request.state == .ready, let id = request.analysisID {
                    self?.state = .ready(try await getAnalysis(id: id, locale: self?.locale ?? .en)); return
                }
                for try await progress in observeAnalysis(requestID: request.id) {
                    guard !Task.isCancelled else { return }; self?.state = .progressing(progress)
                    if progress == .ready, let id = request.analysisID { self?.state = .ready(try await getAnalysis(id: id, locale: self?.locale ?? .en)); return }
                }
            } catch { if !Task.isCancelled { self?.state = .failed } }
        }
    }
}

public struct AnalysisStateView: View {
    @StateObject private var model: AnalysisViewModel
    public init(viewModel: @autoclosure @escaping () -> AnalysisViewModel) { _model = StateObject(wrappedValue: viewModel()) }
    public var body: some View {
        switch model.state {
        case .idle: Button(L10n.text("analysis.generate")) { model.generate() }.disabled(false)
        case .requesting, .progressing: HStack { ProgressView(); Text(L10n.text("analysis.loading")) }.accessibilityElement(children: .combine)
        case .failed: Button(L10n.text("analysis.failure.retry")) { model.generate() }
        case .ready(let analysis): AnalysisResultView(analysis: analysis)
        }
    }
}

public struct AnalysisResultView: View {
    public let analysis: Analysis
    public init(analysis: Analysis) { self.analysis = analysis }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            probabilityRow(L10n.text("match.home", locale: analysis.language), analysis.markets.matchResult.home)
            probabilityRow(L10n.text("match.draw", locale: analysis.language), analysis.markets.matchResult.draw)
            probabilityRow(L10n.text("match.away", locale: analysis.language), analysis.markets.matchResult.away)
            Text(L10n.text("analysis.probability_disclaimer", locale: analysis.language)).font(.footnote).foregroundStyle(.secondary)
            ForEach(analysis.rationale) { item in Text(item.text).accessibilityHint(item.evidenceRefs.joined(separator: ", ")) }
            if !analysis.limitations.isEmpty { Text(L10n.text("analysis.limitations.title", locale: analysis.language)).font(.headline); ForEach(analysis.limitations, id: \.self) { Text($0) } }
        }
    }
    private func probabilityRow(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading) { HStack { Text(label); Spacer(); Text(value, format: .percent.scale(1)) }; ProgressView(value: Double(value), total: 100) }
            .accessibilityElement(children: .combine)
    }
}
