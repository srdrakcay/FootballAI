#if os(iOS)
import CoreDomain
import SwiftUI

struct PaywallView: View {
    /// The match that triggered the paywall, if any. Drives the headline and auto-unlock.
    let context: Fixture?
    var onCreditsAdded: () -> Void = {}

    enum Stage: Equatable { case loading, ready, empty, failed, purchasing, syncing, done, delayed }

    @Environment(SessionStore.self) var session
    @Environment(\.dismiss) var dismiss
    @State var packages: [CreditPackage] = []
    @State var selectedID: String?
    @State var stage: Stage = .loading
    @State var errorText: Text?
    @State var successTrigger = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headline
                    benefits
                    packageList
                    if let errorText {
                        errorText.font(.footnote).foregroundStyle(Pitch.warning).frame(maxWidth: .infinity)
                    }
                }
                .padding(Pitch.screenPadding)
                .padding(.bottom, 140)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) { purchaseBar }
            .pitchScreen()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.headline) }
                        .accessibilityLabel(Text("common.close", bundle: .module))
                        .disabled(stage == .purchasing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CreditPill(available: session.wallet?.available, showsPlus: false)
                        .accessibilityLabel(Text("a11y.credits \(session.wallet?.available ?? 0)", bundle: .module))
                }
            }
        }
        .presentationBackground(Pitch.background)
        .interactiveDismissDisabled(stage == .purchasing || stage == .syncing)
        .sensoryFeedback(.success, trigger: successTrigger)
        .task { await loadPackages() }
    }

    // MARK: Sections

    private var headline: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let context {
                Eyebrow(text: Text("paywall.context \(context.homeTeam.name) \(context.awayTeam.name) \(session.wallet?.analysisCreditCost ?? 1)", bundle: .module))
            }
            Text("paywall.title", bundle: .module).font(.display(38)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("chart.bar.fill", Pitch.homeText, Text("paywall.benefit.markets", bundle: .module))
            benefit("person.fill", Pitch.accent, Text("paywall.benefit.personal", bundle: .module))
            benefit("arrow.counterclockwise", Pitch.awayText, Text("paywall.benefit.reopen", bundle: .module))
        }
    }

    private func benefit(_ symbol: String, _ color: Color, _ text: Text) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.footnote.weight(.semibold)).foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(Pitch.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            text.font(.subheadline).foregroundStyle(Pitch.textSecondary)
        }
    }

    @ViewBuilder private var packageList: some View {
        switch stage {
        case .loading:
            VStack(spacing: 10) { ForEach(0..<3, id: \.self) { _ in SkeletonBlock(height: 68) } }
        case .empty, .failed:
            EmptyStateView(
                symbol: "cart",
                title: Text("paywall.unavailable.title", bundle: .module),
                message: Text("paywall.unavailable.message", bundle: .module),
                actionTitle: Text("common.retry", bundle: .module),
                action: { Task { await loadPackages() } }
            )
        default:
            VStack(spacing: 10) {
                ForEach(packages) { package in packageRow(package) }
            }
        }
    }

    private func packageRow(_ package: CreditPackage) -> some View {
        let selected = package.id == selectedID
        let badgeText = badge(for: package)
        return Button { selectedID = package.id } label: {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(selected ? Pitch.accent : Pitch.draw, lineWidth: selected ? 6 : 2)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        if let credits = package.credits {
                            Text("paywall.pack.credits \(credits)", bundle: .module).font(.body.weight(.bold))
                        } else {
                            Text(package.title).font(.body.weight(.bold))
                        }
                        if let badgeText {
                            badgeText.font(.caption2.weight(.bold))
                                .foregroundStyle(Pitch.onAccent)
                                .padding(.horizontal, 7).frame(minHeight: 20)
                                .background(Pitch.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    if let perCredit = package.localizedPricePerCredit {
                        HStack(spacing: 4) {
                            Text("paywall.pack.per_analysis \(perCredit)", bundle: .module)
                            if let saving = saving(for: package), saving >= 5 {
                                Text(verbatim: "·")
                                Text("paywall.pack.saving \(saving)", bundle: .module).foregroundStyle(Pitch.accent)
                            }
                        }
                        .font(.caption).foregroundStyle(Pitch.textMuted)
                    }
                }
                Spacer()
                Text(package.localizedPrice).font(.body.weight(.bold)).monospacedDigit()
            }
            .foregroundStyle(Pitch.text)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(selected ? Pitch.accentSurface : Pitch.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selected ? Pitch.accent : Pitch.line, lineWidth: 2) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(stage == .purchasing || stage == .syncing)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    @ViewBuilder private var purchaseBar: some View {
        VStack(spacing: 10) {
            switch stage {
            case .syncing:
                HStack(spacing: 10) { ProgressView().tint(Pitch.accent); Text("paywall.syncing", bundle: .module) }
                    .font(.subheadline).frame(maxWidth: .infinity, minHeight: 54)
            case .done:
                Label { Text("paywall.done", bundle: .module) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Pitch.accent) }
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 54)
            case .delayed:
                Text("paywall.delayed", bundle: .module).font(.footnote).foregroundStyle(Pitch.textSecondary).multilineTextAlignment(.center)
                Button { dismiss() } label: { Text("common.ok", bundle: .module) }.buttonStyle(SecondaryButtonStyle())
            default:
                Button { purchase() } label: {
                    if stage == .purchasing { ProgressView().tint(Pitch.onAccent) }
                    else if let selected = selectedPackage {
                        if let credits = selected.credits {
                            Text("paywall.cta \(credits) \(selected.localizedPrice)", bundle: .module)
                        } else {
                            Text("paywall.cta.generic \(selected.localizedPrice)", bundle: .module)
                        }
                    } else {
                        Text("paywall.cta.choose", bundle: .module)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedPackage == nil || stage != .ready)
            }
            Text("paywall.terms", bundle: .module).font(.caption).foregroundStyle(Pitch.textMuted)
            HStack(spacing: 20) {
                NavigationLink { LegalDocumentScreen(document: .terms) } label: { Text("legal.terms", bundle: .module) }
                NavigationLink { LegalDocumentScreen(document: .privacy) } label: { Text("legal.privacy", bundle: .module) }
            }
            .font(.caption).foregroundStyle(Pitch.textSecondary)
        }
        .padding(.horizontal, Pitch.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Pitch.background.shadow(.drop(color: .black.opacity(0.5), radius: 12, y: -4)))
    }

    // MARK: Logic

    private var selectedPackage: CreditPackage? { packages.first { $0.id == selectedID } }

    /// Middle pack is the anchor ("most popular"); the cheapest per-credit pack is "best value".
    private func badge(for package: CreditPackage) -> Text? {
        guard packages.count >= 2 else { return nil }
        let best = packages.filter { $0.pricePerCredit != nil }.min { ($0.pricePerCredit ?? 0) < ($1.pricePerCredit ?? 0) }
        if packages.count >= 3, package.id == packages[packages.count / 2].id, package.id != best?.id {
            return Text("paywall.badge.popular", bundle: .module)
        }
        if package.id == best?.id, let saving = saving(for: package), saving >= 5 {
            return Text("paywall.badge.best", bundle: .module)
        }
        return nil
    }

    /// Percentage saved per credit compared with the smallest pack.
    private func saving(for package: CreditPackage) -> Int? {
        guard let base = packages.first?.pricePerCredit, base > 0, let unit = package.pricePerCredit, package.id != packages.first?.id else { return nil }
        let ratio = NSDecimalNumber(decimal: (base - unit) / base).doubleValue
        return Int((ratio * 100).rounded())
    }

    private func loadPackages() async {
        stage = .loading
        errorText = nil
        do {
            packages = try await session.creditPackages()
            if packages.isEmpty { stage = .empty; return }
            selectedID = packages.count >= 3 ? packages[packages.count / 2].id : packages.last?.id
            stage = .ready
        } catch {
            stage = .failed
        }
    }

    private func purchase() {
        guard let package = selectedPackage else { return }
        let previousBalance = session.wallet?.balance ?? 0
        stage = .purchasing
        errorText = nil
        Task {
            do {
                switch try await session.purchase(package) {
                case .cancelled:
                    stage = .ready
                case .purchased:
                    stage = .syncing
                    if await session.waitForCredits(above: previousBalance) {
                        stage = .done
                        successTrigger += 1
                        onCreditsAdded()
                        try? await Task.sleep(for: .seconds(1.1))
                        dismiss()
                    } else {
                        stage = .delayed
                    }
                }
            } catch {
                stage = .ready
                errorText = Text("paywall.error", bundle: .module)
            }
        }
    }
}
#endif
