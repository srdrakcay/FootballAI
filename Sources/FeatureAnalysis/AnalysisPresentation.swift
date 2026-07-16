import CoreDomain
import CoreLocalization
import Foundation
import SwiftUI

@MainActor
public final class AnalysisViewModel: ObservableObject {
    public enum State: Equatable { case loadingExisting, idle, requesting, progressing(AnalysisState), ready(Analysis), insufficientCredits, failed }
    @Published public private(set) var state: State = .loadingExisting
    private let fixtureKey: FixtureKey; private let locale: SupportedLocale
    private let findExistingAnalysis: any FindExistingAnalysisUseCase
    private let requestAnalysis: any RequestAnalysisUseCase
    private let observeAnalysis: any ObserveAnalysisUseCase
    private let getAnalysis: any GetLocalizedAnalysisUseCase
    private var task: Task<Void, Never>?

    public init(fixtureKey: FixtureKey, locale: SupportedLocale, findExistingAnalysis: any FindExistingAnalysisUseCase, requestAnalysis: any RequestAnalysisUseCase, observeAnalysis: any ObserveAnalysisUseCase, getAnalysis: any GetLocalizedAnalysisUseCase) {
        self.fixtureKey = fixtureKey; self.locale = locale; self.findExistingAnalysis = findExistingAnalysis; self.requestAnalysis = requestAnalysis
        self.observeAnalysis = observeAnalysis; self.getAnalysis = getAnalysis
    }
    deinit { task?.cancel() }
    public func loadExisting() {
        guard state == .loadingExisting else { return }
        task?.cancel()
        task = Task { [weak self, findExistingAnalysis] in
            do {
                guard let self else { return }
                if let analysis = try await findExistingAnalysis(fixtureKey: self.fixtureKey, locale: self.locale) {
                    self.state = .ready(analysis)
                } else {
                    self.state = .idle
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .idle
            }
        }
    }
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
            } catch {
                guard !Task.isCancelled else { return }
                if case DomainError.insufficientCredits = error {
                    self?.state = .insufficientCredits
                } else {
                    self?.state = .failed
                }
            }
        }
    }
}

public struct AnalysisStateView: View {
    @StateObject private var model: AnalysisViewModel
    private let canAffordAnalysis: Bool
    private let retryTrigger: Int
    private let onInsufficientCredits: () -> Void
    private let onAnalysisReady: () -> Void

    public init(
        viewModel: @autoclosure @escaping () -> AnalysisViewModel,
        canAffordAnalysis: Bool = true,
        retryTrigger: Int = 0,
        onInsufficientCredits: @escaping () -> Void = {},
        onAnalysisReady: @escaping () -> Void = {}
    ) {
        _model = StateObject(wrappedValue: viewModel())
        self.canAffordAnalysis = canAffordAnalysis
        self.retryTrigger = retryTrigger
        self.onInsufficientCredits = onInsufficientCredits
        self.onAnalysisReady = onAnalysisReady
    }

    public var body: some View {
        Group {
            switch model.state {
            case .loadingExisting:
                HStack { ProgressView(); Text(L10n.text("analysis.loading")) }.accessibilityElement(children: .combine)
            case .idle:
                Button(L10n.text("analysis.generate")) { beginAnalysis() }
            case .requesting, .progressing:
                HStack { ProgressView(); Text(L10n.text("analysis.loading")) }.accessibilityElement(children: .combine)
            case .insufficientCredits:
                Button(L10n.text("analysis.credits.get")) { onInsufficientCredits() }
            case .failed:
                Button(L10n.text("analysis.failure.retry")) { beginAnalysis() }
            case .ready(let analysis):
                AnalysisResultView(analysis: analysis)
            }
        }
        .task { model.loadExisting() }
        .onChange(of: model.state) { _, state in
            if state == .insufficientCredits { onInsufficientCredits() }
            if case .ready = state { onAnalysisReady() }
        }
        .onChange(of: retryTrigger) { _, _ in model.generate() }
    }

    private func beginAnalysis() {
        if canAffordAnalysis { model.generate() }
        else { onInsufficientCredits() }
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
