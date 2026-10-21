#if os(iOS)
import CoreDomain
import SwiftUI

/// Competitions offered by the current data provider (football-data.org codes).
enum Competitions {
    static let all = ["CL", "PL", "PD", "SA", "BL1", "FL1", "DED", "PPL", "ELC"]

    static func name(_ code: String) -> String {
        switch code {
        case "CL": String(localized: "league.CL", bundle: .module)
        case "PL": "Premier League"
        case "PD": "La Liga"
        case "SA": "Serie A"
        case "BL1": "Bundesliga"
        case "FL1": "Ligue 1"
        case "DED": "Eredivisie"
        case "PPL": "Primeira Liga"
        case "ELC": "Championship"
        default: code
        }
    }
}

// MARK: - First launch

struct AIProfileOnboardingView: View {
    let completion: (AIProfile) -> Void
    @State var step = 0
    @State var profile = AIProfile.default

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(0..<2) { index in
                        Capsule().fill(index <= step ? Pitch.accent : Pitch.line).frame(height: 4)
                    }
                }
                Button { completion(profile) } label: { Text("common.skip", bundle: .module) }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Pitch.textMuted)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, Pitch.screenPadding)
            .padding(.top, 8)

            if step == 0 {
                welcome.transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("onboarding.profile.title", bundle: .module).font(.display(34))
                            Text("onboarding.profile.subtitle", bundle: .module)
                                .font(.subheadline).foregroundStyle(Pitch.textMuted)
                        }
                        AIProfileForm(profile: $profile)
                    }
                    .padding(Pitch.screenPadding)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if step == 0 { withAnimation(.snappy) { step = 1 } } else { completion(profile) }
            } label: {
                step == 0 ? Text("onboarding.cta.start", bundle: .module) : Text("onboarding.cta.finish", bundle: .module)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Pitch.screenPadding)
            .padding(.bottom, 8)
            .background(Pitch.background)
        }
        .pitchScreen()
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: Text(verbatim: "NinetyLens"))
                Text("onboarding.welcome.title", bundle: .module).font(.display(44)).fixedSize(horizontal: false, vertical: true)
                Text("onboarding.welcome.body", bundle: .module).font(.body).foregroundStyle(Pitch.textMuted)
            }
            VStack(alignment: .leading, spacing: 14) {
                benefit("chart.bar.fill", Pitch.homeText, Text("onboarding.welcome.point1", bundle: .module))
                benefit("person.fill", Pitch.accent, Text("onboarding.welcome.point2", bundle: .module))
                benefit("gift.fill", Pitch.awayText, Text("onboarding.welcome.point3", bundle: .module))
            }
            Spacer()
        }
        .padding(Pitch.screenPadding)
    }

    private func benefit(_ symbol: String, _ color: Color, _ text: Text) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(Pitch.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            text.font(.subheadline).foregroundStyle(Pitch.textSecondary)
        }
    }
}

// MARK: - Editing from Profile

struct AIProfileEditorSheet: View {
    @Environment(SessionStore.self) var session
    @Environment(\.dismiss) var dismiss
    @State var draft: AIProfile = .default
    @State var isSaving = false
    @State var failed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                AIProfileForm(profile: $draft).padding(Pitch.screenPadding)
            }
            .scrollIndicators(.hidden)
            .pitchScreen()
            .navigationTitle(Text("profile.ai.title", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel", bundle: .module) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: {
                        if isSaving { ProgressView() } else { Text("common.save", bundle: .module).bold() }
                    }
                    .disabled(isSaving || draft == session.profile)
                }
            }
            .alert(Text("error.save_failed", bundle: .module), isPresented: $failed) {
                Button { } label: { Text("common.ok", bundle: .module) }
            }
        }
        .onAppear { draft = session.profile }
        .presentationBackground(Pitch.background)
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await session.saveProfile(draft)
                dismiss()
            } catch {
                failed = true
            }
            isSaving = false
        }
    }
}

// MARK: - Shared form

struct AIProfileForm: View {
    @Binding var profile: AIProfile
    @Environment(MatchesStore.self) var matches
    @Environment(SessionStore.self) var session
    @State var teamQuery = ""
    @FocusState var searching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            teamSection
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: Text("profile.form.leagues", bundle: .module))
                FlowLayout(spacing: 8) {
                    ForEach(Competitions.all, id: \.self) { code in
                        let selected = profile.competitionIds.contains(code)
                        Button {
                            if selected { profile.competitionIds.removeAll { $0 == code } }
                            else { profile.competitionIds.append(code) }
                        } label: { Text(Competitions.name(code)) }
                        .buttonStyle(ChipButtonStyle(selected: selected))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: Text("profile.form.style", bundle: .module))
                ForEach(AnalysisStyle.allCases, id: \.self) { style in
                    styleRow(style)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: Text("profile.form.focus", bundle: .module))
                FlowLayout(spacing: 8) {
                    ForEach(FocusMarket.allCases, id: \.self) { market in
                        let selected = profile.focusMarkets.contains(market)
                        Button {
                            if selected, profile.focusMarkets.count > 1 { profile.focusMarkets.removeAll { $0 == market } }
                            else if !selected { profile.focusMarkets.append(market) }
                        } label: { Text(market.title) }
                        .buttonStyle(ChipButtonStyle(selected: selected))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: profile)
    }

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: Text("profile.form.team", bundle: .module))
            if let team = profile.favoriteTeam, teamQuery.isEmpty, !searching {
                HStack(spacing: 12) {
                    TeamBadge(name: team.name, side: .home, size: 32)
                    Text(team.name).font(.body.weight(.semibold))
                    Spacer()
                    Button { profile.favoriteTeam = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(Pitch.textMuted)
                    }
                    .accessibilityLabel(Text("profile.form.team.clear", bundle: .module))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(Pitch.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Pitch.accentLine) }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Pitch.textMuted)
                    TextField(text: $teamQuery) { Text("profile.form.team.placeholder", bundle: .module) }
                        .focused($searching)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(Pitch.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Pitch.line) }

                let results = teamResults
                if !results.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(results, id: \.id) { team in
                            Button {
                                profile.favoriteTeam = team
                                teamQuery = ""
                                searching = false
                            } label: {
                                HStack(spacing: 12) {
                                    TeamBadge(name: team.name, size: 28)
                                    Text(team.name).foregroundStyle(Pitch.text)
                                    Spacer()
                                }
                                .frame(minHeight: 46)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if team.id != results.last?.id { Divider().overlay(Pitch.hairline) }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(Pitch.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else if !teamQuery.isEmpty {
                    Text("profile.form.team.empty", bundle: .module).font(.footnote).foregroundStyle(Pitch.textMuted)
                }
            }
        }
    }

    /// Teams from every fixture the app has seen so far (loaded days and favorites).
    private var teamResults: [FavoriteTeam] {
        var seen: [String: FavoriteTeam] = [:]
        var fixtures = session.favoriteFixtures
        for state in matches.days.values { if case .loaded(let list, _) = state { fixtures += list } }
        for fixture in fixtures {
            if profile.competitionIds.isEmpty || profile.competitionIds.contains(fixture.competition.id.rawValue) {
                for team in [fixture.homeTeam, fixture.awayTeam] { seen[team.id.rawValue] = FavoriteTeam(id: team.id.rawValue, name: team.name) }
            }
        }
        let all = seen.values.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        let query = teamQuery.trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return searching ? Array(all.prefix(8)) : [] }
        return Array(all.filter { $0.name.localizedStandardContains(query) }.prefix(8))
    }

    private func styleRow(_ style: AnalysisStyle) -> some View {
        let selected = profile.style == style
        return Button { profile.style = style } label: {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(selected ? Pitch.accent : Pitch.draw, lineWidth: selected ? 6 : 2)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.title).font(.body.weight(.semibold)).foregroundStyle(Pitch.text)
                    Text(style.subtitle).font(.footnote).foregroundStyle(Pitch.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(selected ? Pitch.accentSurface : Pitch.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(selected ? Pitch.accent : Pitch.line) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension AnalysisStyle {
    var title: String {
        switch self {
        case .brief: String(localized: "style.brief.title", bundle: .module)
        case .balanced: String(localized: "style.balanced.title", bundle: .module)
        case .deep: String(localized: "style.deep.title", bundle: .module)
        }
    }
    var subtitle: String {
        switch self {
        case .brief: String(localized: "style.brief.subtitle", bundle: .module)
        case .balanced: String(localized: "style.balanced.subtitle", bundle: .module)
        case .deep: String(localized: "style.deep.subtitle", bundle: .module)
        }
    }
}

extension FocusMarket {
    var title: String {
        switch self {
        case .matchResult: String(localized: "focus.matchResult", bundle: .module)
        case .goals: String(localized: "focus.goals", bundle: .module)
        case .bothTeamsScore: String(localized: "focus.bothTeamsScore", bundle: .module)
        case .scorelines: String(localized: "focus.scorelines", bundle: .module)
        }
    }
}

/// Wrapping row layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row(indices: [index], width: size.width, height: size.height))
            } else {
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width = needed
                rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            }
        }
        return rows
    }
}
#endif
