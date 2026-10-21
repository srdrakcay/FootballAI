#if os(iOS)
import CoreDomain
import SwiftUI

struct ProfileScreen: View {
    @Environment(SessionStore.self) var session
    @Environment(\.openURL) var openURL
    @AppStorage("footballai.onboarding.completed.v2") var completedOnboarding = true
    @State var showsPaywall = false
    @State var showsEditor = false
    @State var confirmSignOut = false
    @State var confirmDelete = false
    @State var working = false
    @State var failure: Text?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("tab.profile", bundle: .module).font(.display(38)).padding(.top, 8)
                walletCard
                aiProfileSection
                settingsSection
            }
            .padding(.horizontal, Pitch.screenPadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { await session.refreshLibrary() }
        .pitchScreen()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsPaywall) { PaywallView(context: nil) }
        .sheet(isPresented: $showsEditor) { AIProfileEditorSheet() }
        .confirmationDialog(Text("profile.signout.confirm", bundle: .module), isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button(role: .destructive) { run { try await session.signOut() } } label: { Text("profile.signout", bundle: .module) }
        } message: { Text("profile.signout.message", bundle: .module) }
        .alert(Text("profile.delete.confirm", bundle: .module), isPresented: $confirmDelete) {
            Button(role: .cancel) { } label: { Text("common.cancel", bundle: .module) }
            Button(role: .destructive) { run { try await session.deleteAccount() } } label: { Text("profile.delete.action", bundle: .module) }
        } message: { Text("profile.delete.message", bundle: .module) }
        .alert(Text("error.action_failed", bundle: .module), isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button { failure = nil } label: { Text("common.ok", bundle: .module) }
        } message: { failure }
        .overlay { if working { ProgressView().controlSize(.large).tint(Pitch.accent) } }
    }

    // MARK: Wallet

    private var walletCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("profile.wallet.balance", bundle: .module).font(.footnote).foregroundStyle(Pitch.textMuted)
                    Group {
                        if let wallet = session.wallet { Text(wallet.available, format: .number).contentTransition(.numericText()) }
                        else { Text(verbatim: "–") }
                    }
                    .font(.display(48))
                }
                Spacer()
                Button { showsPaywall = true } label: { Text("profile.wallet.buy", bundle: .module) }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(width: 130)
            }
            if let wallet = session.wallet {
                Text("profile.wallet.cost \(wallet.analysisCreditCost)", bundle: .module).font(.caption).foregroundStyle(Pitch.textMuted)
            }
            if !session.ledger.isEmpty {
                VStack(spacing: 0) {
                    ForEach(session.ledger.prefix(3)) { entry in
                        LedgerRow(entry: entry)
                        Divider().overlay(Pitch.hairline)
                    }
                    NavigationLink { LedgerScreen() } label: {
                        HStack {
                            Text("profile.wallet.all", bundle: .module)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold))
                        }
                        .font(.footnote.weight(.semibold)).foregroundStyle(Pitch.accent)
                        .frame(minHeight: 44)
                    }
                }
            }
        }
        .pitchCard(padding: 18)
        .animation(.snappy, value: session.wallet)
    }

    // MARK: AI profile

    private var aiProfileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: Text("profile.ai.title", bundle: .module))
            VStack(spacing: 0) {
                settingsRow(Text("profile.form.team", bundle: .module), value: session.profile.favoriteTeam?.name ?? String(localized: "profile.ai.none", bundle: .module)) { showsEditor = true }
                Divider().overlay(Pitch.hairline)
                settingsRow(Text("profile.form.style", bundle: .module), value: session.profile.style.title) { showsEditor = true }
                Divider().overlay(Pitch.hairline)
                settingsRow(Text("profile.form.focus", bundle: .module), value: session.profile.focusMarkets.map(\.title).joined(separator: ", ")) { showsEditor = true }
                Divider().overlay(Pitch.hairline)
                settingsRow(Text("profile.language", bundle: .module), value: Locale.current.localizedString(forLanguageCode: SupportedLocale.app.rawValue)?.capitalized ?? "") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
            .background(Pitch.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Pitch.hairline) }
            Text("profile.ai.footer", bundle: .module).font(.caption).foregroundStyle(Pitch.textMuted).padding(.horizontal, 4)
        }
    }

    private func settingsRow(_ title: Text, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                title.foregroundStyle(Pitch.text)
                Spacer()
                Text(value).foregroundStyle(Pitch.textMuted).lineLimit(1)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Pitch.textMuted)
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Settings

    private var settingsSection: some View {
        VStack(spacing: 0) {
            NavigationLink { LegalDocumentScreen(document: .privacy) } label: { linkRow(Text("legal.privacy", bundle: .module)) }
            Divider().overlay(Pitch.hairline)
            NavigationLink { LegalDocumentScreen(document: .terms) } label: { linkRow(Text("legal.terms", bundle: .module)) }
            Divider().overlay(Pitch.hairline)
            Button { confirmSignOut = true } label: { linkRow(Text("profile.signout", bundle: .module), chevron: false) }
            Divider().overlay(Pitch.hairline)
            Button { confirmDelete = true } label: {
                linkRow(Text("profile.delete", bundle: .module), chevron: false).foregroundStyle(Pitch.danger)
            }
        }
        .buttonStyle(.plain)
        .disabled(working)
        .background(Pitch.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Pitch.hairline) }
    }

    private func linkRow(_ title: Text, chevron: Bool = true) -> some View {
        HStack {
            title
            Spacer()
            if chevron { Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Pitch.textMuted) }
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        working = true
        Task {
            do {
                try await operation()
                completedOnboarding = false
                await session.start()
            } catch {
                failure = Text("error.try_again", bundle: .module)
            }
            working = false
        }
    }
}

struct LedgerRow: View {
    let entry: CreditLedgerEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                title.font(.subheadline).lineLimit(1)
                HStack(spacing: 4) {
                    kind
                    Text(verbatim: "·")
                    Text(entry.createdAt, format: .dateTime.day().month(.abbreviated))
                }
                .font(.caption).foregroundStyle(Pitch.textMuted)
            }
            Spacer()
            Text(entry.delta, format: .number.sign(strategy: .always()))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(entry.delta > 0 ? Pitch.accent : Pitch.textSecondary)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var title: Text {
        if let label = entry.label { return Text(label) }
        return switch entry.kind {
        case .purchase: Text("ledger.purchase.title \(entry.delta)", bundle: .module)
        case .welcomeGrant: Text("ledger.welcome", bundle: .module)
        case .refund: Text("ledger.refund", bundle: .module)
        case .analysisUnlock: Text("ledger.analysis", bundle: .module)
        case .adjustment: Text("ledger.adjustment", bundle: .module)
        }
    }

    private var kind: Text {
        switch entry.kind {
        case .purchase: Text("ledger.kind.purchase", bundle: .module)
        case .welcomeGrant: Text("ledger.kind.gift", bundle: .module)
        case .refund: Text("ledger.kind.refund", bundle: .module)
        case .analysisUnlock: Text("ledger.kind.analysis", bundle: .module)
        case .adjustment: Text("ledger.kind.adjustment", bundle: .module)
        }
    }
}

struct LedgerScreen: View {
    @Environment(SessionStore.self) var session
    var body: some View {
        List {
            ForEach(session.ledger) { entry in
                LedgerRow(entry: entry).listRowBackground(Pitch.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if session.ledger.isEmpty {
                EmptyStateView(symbol: "list.bullet", title: Text("ledger.empty.title", bundle: .module), message: Text("ledger.empty.message", bundle: .module))
                    .padding()
            }
        }
        .refreshable { await session.refreshLedger() }
        .pitchScreen()
        .navigationTitle(Text("ledger.title", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
