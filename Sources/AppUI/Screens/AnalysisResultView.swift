#if os(iOS)
import CoreDomain
import SwiftUI

struct AnalysisResultView: View {
    let fixture: Fixture
    let value: UnlockedAnalysis
    let profile: AIProfile

    private var markets: MatchAnalysis.Markets { value.analysis.markets }
    private var personal: PersonalAnalysis { value.personal }

    var body: some View {
        VStack(spacing: 14) {
            summaryCard
            if let forYou = personal.forYou, !forYou.isEmpty { forYouCard(forYou) }
            reasonsCard
            footer
        }
    }

    // MARK: Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: Text("analysis.summary.eyebrow", bundle: .module))
                    Text(personal.headline).font(.display(26)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                ConfidenceChip(level: value.analysis.confidence.level)
            }

            VStack(spacing: 8) {
                OutcomeBar(home: markets.matchResult.homePct, draw: markets.matchResult.drawPct, away: markets.matchResult.awayPct)
                HStack(alignment: .top) {
                    outcome(markets.matchResult.homePct, Text(fixture.homeTeam.name), Pitch.homeText, .leading)
                    outcome(markets.matchResult.drawPct, Text("analysis.draw", bundle: .module), Pitch.textSecondary, .center)
                    outcome(markets.matchResult.awayPct, Text(fixture.awayTeam.name), Pitch.awayText, .trailing)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                market(Text("analysis.market.over25", bundle: .module), markets.goals25.overPct, emphasized: profile.focusMarkets.contains(.goals))
                market(Text("analysis.market.btts", bundle: .module), markets.bothTeamsScore.yesPct, emphasized: profile.focusMarkets.contains(.bothTeamsScore))
            }

            if !markets.likelyScores.isEmpty {
                HStack(spacing: 8) {
                    Text("analysis.market.scores", bundle: .module).font(.caption).foregroundStyle(Pitch.textMuted)
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(Array(markets.likelyScores.sorted { $0.pct > $1.pct }.prefix(4).enumerated()), id: \.element.id) { index, score in
                                Text(verbatim: "\(score.home)-\(score.away) · \(percent(score.pct))")
                                    .font(.footnote.weight(index == 0 ? .bold : .semibold).monospacedDigit())
                                    .padding(.horizontal, 10).frame(minHeight: 30)
                                    .foregroundStyle(index == 0 ? Pitch.onAccent : Pitch.text)
                                    .background(index == 0 ? Pitch.text : Pitch.surfaceRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }

            Text(personal.summary).font(.subheadline).foregroundStyle(Pitch.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .pitchCard(padding: 18)
    }

    private func outcome(_ value: Int, _ label: Text, _ color: Color, _ alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(percent(value)).font(.display(28)).foregroundStyle(color)
            label.font(.caption).foregroundStyle(Pitch.textMuted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
    }

    private func market(_ title: Text, _ value: Int, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            title.font(.caption).foregroundStyle(Pitch.textMuted)
            Text(percent(value)).font(.display(24))
            MeterBar(value: value)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Pitch.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(emphasized ? Pitch.accentLine : .clear) }
        .accessibilityElement(children: .combine)
    }

    // MARK: Personal

    private func forYouCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let side = personal.favoriteSide {
                    Eyebrow(text: Text("analysis.for_you.team \(side == .home ? fixture.homeTeam.name : fixture.awayTeam.name)", bundle: .module))
                } else {
                    Eyebrow(text: Text("analysis.for_you", bundle: .module))
                }
            }
            Text(text).font(.subheadline).foregroundStyle(Pitch.text.opacity(0.92)).fixedSize(horizontal: false, vertical: true)
        }
        .pitchCard(highlighted: true)
    }

    private var reasonsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("analysis.reasons.title", bundle: .module).font(.subheadline.weight(.semibold))
            ForEach(personal.keyFactors) { factor in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(factor.section.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: 0xA8D1FF))
                        .padding(.horizontal, 8).frame(minHeight: 22)
                        .background(Color(hex: 0x1B2A3A), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text(factor.text).font(.footnote).foregroundStyle(Pitch.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider().overlay(Pitch.hairline)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "info.circle").font(.footnote).foregroundStyle(Pitch.warning)
                VStack(alignment: .leading, spacing: 4) {
                    if let note = personal.watchNote { Text(note) }
                    Text("analysis.disclaimer", bundle: .module)
                }
                .font(.caption).foregroundStyle(Pitch.textMuted)
            }
        }
        .pitchCard()
    }

    @ViewBuilder private var footer: some View {
        if let generated = value.analysis.generatedDate {
            Text("analysis.updated \(generated.formatted(.relative(presentation: .named)))", bundle: .module)
                .font(.caption2).foregroundStyle(Pitch.textMuted)
                .frame(maxWidth: .infinity)
        }
    }
}

func percent(_ value: Int) -> String {
    (Double(value) / 100).formatted(.percent.precision(.fractionLength(0)))
}

struct ConfidenceChip: View {
    let level: ConfidenceLevel
    var body: some View {
        let (text, foreground, background): (Text, Color, Color) = switch level {
        case .high: (Text("confidence.high", bundle: .module), Pitch.onAccent, Pitch.accent)
        case .medium: (Text("confidence.medium", bundle: .module), Pitch.warning, Pitch.warningSurface)
        case .low: (Text("confidence.low", bundle: .module), Pitch.textSecondary, Pitch.surfaceRaised)
        }
        text.font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10).frame(minHeight: 26)
            .background(background, in: Capsule())
    }
}

extension EvidenceSection {
    var title: String {
        switch self {
        case .recentForm: String(localized: "evidence.recentForm", bundle: .module)
        case .headToHead: String(localized: "evidence.headToHead", bundle: .module)
        case .standings: String(localized: "evidence.standings", bundle: .module)
        case .squadAvailability: String(localized: "evidence.squad", bundle: .module)
        case .lineups: String(localized: "evidence.lineups", bundle: .module)
        case .weather: String(localized: "evidence.weather", bundle: .module)
        }
    }
}

// MARK: - Free statistics

struct FormSummaryCard: View {
    let fixture: Fixture
    let form: TeamFormPair
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("insights.form.title", bundle: .module).font(.subheadline.weight(.semibold))
                Spacer()
                if compact { Text("insights.free", bundle: .module).font(.caption).foregroundStyle(Pitch.textMuted) }
            }
            row(fixture.homeTeam.name, form.home)
            row(fixture.awayTeam.name, form.away)
        }
        .pitchCard()
    }

    private func row(_ name: String, _ value: TeamRecentForm) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.subheadline).foregroundStyle(Pitch.textSecondary).lineLimit(1)
                Spacer()
                HStack(spacing: 5) { ForEach(Array(value.form.suffix(5).enumerated()), id: \.offset) { FormBadge(result: $0.element) } }
            }
            if !compact {
                Text("insights.form.record \(value.wins) \(value.draws) \(value.losses) \(value.goalsFor) \(value.goalsAgainst)", bundle: .module)
                    .font(.caption).foregroundStyle(Pitch.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct HeadToHeadCard: View {
    let matches: [FixtureInsightMatch]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("insights.h2h.title", bundle: .module).font(.subheadline.weight(.semibold)).padding(.bottom, 6)
            ForEach(Array(matches.suffix(5).reversed())) { match in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(match.homeTeamName ?? "—").font(.footnote.weight(.semibold)).lineLimit(1)
                        Text(match.awayTeamName ?? "—").font(.footnote).foregroundStyle(Pitch.textSecondary).lineLimit(1)
                    }
                    Spacer()
                    Text(verbatim: "\(match.homeGoals.map(String.init) ?? "–") : \(match.awayGoals.map(String.init) ?? "–")")
                        .font(.display(20)).monospacedDigit()
                    if let date = match.utcDate.flatMap(ISODate.parse) {
                        Text(date, format: .dateTime.month(.abbreviated).year(.twoDigits))
                            .font(.caption2).foregroundStyle(Pitch.textMuted).frame(width: 52, alignment: .trailing)
                    }
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                Divider().overlay(Pitch.hairline)
            }
        }
        .pitchCard()
    }
}

struct StandingsCard: View {
    let fixture: Fixture
    let standings: TeamStandingPair
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("insights.standings.title", bundle: .module).font(.subheadline.weight(.semibold))
            row(fixture.homeTeam.name, standings.home, Pitch.homeText)
            row(fixture.awayTeam.name, standings.away, Pitch.awayText)
        }
        .pitchCard()
    }

    private func row(_ name: String, _ value: TeamStanding, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Text(value.position.map { "\($0)." } ?? "–").font(.display(22)).foregroundStyle(color).frame(width: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("insights.standings.detail \(value.playedGames ?? 0) \(value.goalDifference ?? 0)", bundle: .module)
                    .font(.caption).foregroundStyle(Pitch.textMuted)
            }
            Spacer()
            Text("insights.standings.points \(value.points ?? 0)", bundle: .module).font(.subheadline.weight(.bold))
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
