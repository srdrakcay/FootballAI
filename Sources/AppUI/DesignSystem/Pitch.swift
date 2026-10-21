#if os(iOS)
import SwiftUI

/// "Pitch Night" design tokens. One ground, one accent, and a blue/orange pair for home/away
/// (told apart by lightness as well as hue, so they stay distinct for colour-blind readers).
public enum Pitch {
    static let background = Color(hex: 0x0A0D0B)
    static let surface = Color(hex: 0x131815)
    static let surfaceRaised = Color(hex: 0x1B221E)
    static let tabBar = Color(hex: 0x0E120F)
    static let line = Color(hex: 0x26302A)
    static let hairline = Color(hex: 0x1F2722)

    static let text = Color(hex: 0xF2F5F1)
    static let textSecondary = Color(hex: 0xC9D1CB)
    static let textMuted = Color(hex: 0x9AA69F)

    static let accent = Color(hex: 0xC8F04A)
    static let accentBright = Color(hex: 0xE2FF8A)
    static let accentSurface = Color(hex: 0x151C10)
    static let accentLine = Color(hex: 0x3A4A1C)
    static let onAccent = Color(hex: 0x0A0D0B)

    static let home = Color(hex: 0x5AA9FF)
    static let homeText = Color(hex: 0x8EC5FF)
    static let homeSurface = Color(hex: 0x1F3550)
    static let away = Color(hex: 0xFF9F43)
    static let awayText = Color(hex: 0xFFBE80)
    static let awaySurface = Color(hex: 0x4A2E14)
    static let draw = Color(hex: 0x6B7570)

    static let warning = Color(hex: 0xFFD66B)
    static let warningSurface = Color(hex: 0x2A2614)
    static let danger = Color(hex: 0xFF8A8A)
    static let loss = Color(hex: 0x5A2525)
    static let lossText = Color(hex: 0xFFD6D6)

    static let radius: CGFloat = 18
    static let screenPadding: CGFloat = 20
}

extension Font {
    /// Condensed scoreboard face for titles and numbers.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

// MARK: - Surfaces

struct PitchCard: ViewModifier {
    var highlighted = false
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlighted ? Pitch.accentSurface : Pitch.surface, in: RoundedRectangle(cornerRadius: Pitch.radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Pitch.radius, style: .continuous)
                    .strokeBorder(highlighted ? Pitch.accentLine : Pitch.line, lineWidth: 1)
            }
    }
}

extension View {
    func pitchCard(highlighted: Bool = false, padding: CGFloat = 16) -> some View {
        modifier(PitchCard(highlighted: highlighted, padding: padding))
    }

    func pitchScreen() -> some View {
        background(Pitch.background.ignoresSafeArea())
            .foregroundStyle(Pitch.text)
            .toolbarBackground(Pitch.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Pitch.onAccent)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Pitch.accent.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Pitch.text)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Pitch.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Pitch.line) }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct ChipButtonStyle: ButtonStyle {
    let selected: Bool
    var strong = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(selected ? .semibold : .medium))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .foregroundStyle(selected ? (strong ? Pitch.onAccent : Pitch.accentBright) : Pitch.text)
            .background {
                Capsule().fill(selected ? (strong ? Pitch.text : Pitch.accentSurface) : Color.clear)
            }
            .overlay { Capsule().strokeBorder(selected ? (strong ? Pitch.text : Pitch.accent) : Pitch.line) }
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule())
    }
}

// MARK: - Building blocks

struct CreditPill: View {
    let available: Int?
    var showsPlus = true
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill").font(.footnote).foregroundStyle(Pitch.accent)
            Group {
                if let available { Text(available, format: .number).contentTransition(.numericText()) }
                else { Text(verbatim: "–") }
            }
            .font(.subheadline.weight(.semibold).monospacedDigit())
            if showsPlus {
                Rectangle().fill(Pitch.line).frame(width: 1, height: 18)
                Image(systemName: "plus").font(.footnote.weight(.bold))
            }
        }
        .foregroundStyle(Pitch.text)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Pitch.surfaceRaised, in: Capsule())
        .overlay { Capsule().strokeBorder(Pitch.line) }
        .animation(.snappy, value: available)
    }
}

struct TeamBadge: View {
    enum Side { case home, away, neutral }
    let name: String
    var side: Side = .neutral
    var size: CGFloat = 34

    private var initials: String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" }).filter { !$0.isEmpty }
        let letters = words.count >= 2 ? words.prefix(2).compactMap(\.first) : Array(name.prefix(2))
        return String(letters).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(side == .away ? Color(hex: 0xFFE2C4) : side == .home ? Color(hex: 0xCFE5FF) : Pitch.text)
            .frame(width: size, height: size)
            .background(side == .away ? Pitch.awaySurface : side == .home ? Pitch.homeSurface : Pitch.surfaceRaised, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Three-segment home / draw / away bar.
struct OutcomeBar: View {
    let home: Int
    let draw: Int
    let away: Int
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let total = max(1, home + draw + away)
            let usable = proxy.size.width - 6
            HStack(spacing: 3) {
                Capsule().fill(Pitch.home).frame(width: max(2, usable * CGFloat(home) / CGFloat(total)))
                Capsule().fill(Pitch.draw).frame(width: max(2, usable * CGFloat(draw) / CGFloat(total)))
                Capsule().fill(Pitch.away).frame(width: max(2, usable * CGFloat(away) / CGFloat(total)))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(Text("a11y.outcome_bar \(home) \(draw) \(away)", bundle: .module))
    }
}

struct MeterBar: View {
    let value: Int
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Pitch.line)
                Capsule().fill(Pitch.accent).frame(width: proxy.size.width * CGFloat(min(max(value, 0), 100)) / 100)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

struct FormBadge: View {
    let result: String
    var body: some View {
        let (background, foreground): (Color, Color) = switch result {
        case "W": (Pitch.accent, Pitch.onAccent)
        case "D": (Color(hex: 0x3A423D), Pitch.text)
        default: (Pitch.loss, Pitch.lossText)
        }
        Text(FormatStyleHelpers.formLetter(result))
            .font(.caption.weight(.bold))
            .frame(width: 26, height: 26)
            .background(background, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .foregroundStyle(foreground)
    }
}

struct SectionLabel: View {
    let text: Text
    var body: some View {
        text.font(.footnote.weight(.semibold)).foregroundStyle(Pitch.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Eyebrow: View {
    let text: Text
    var color: Color = Pitch.accent
    var body: some View {
        text.font(.caption.weight(.semibold)).tracking(0.4).textCase(.uppercase).foregroundStyle(color)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: Text
    let message: Text
    var actionTitle: Text?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 30, weight: .medium)).foregroundStyle(Pitch.textMuted)
            title.font(.headline)
            message.font(.subheadline).foregroundStyle(Pitch.textMuted).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) { actionTitle }.buttonStyle(SecondaryButtonStyle()).frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .pitchCard()
    }
}

/// Lightweight skeleton block for loading states.
struct SkeletonBlock: View {
    var height: CGFloat = 14
    var width: CGFloat? = nil
    @State var phase = false
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Pitch.surfaceRaised)
            .frame(width: width, height: height)
            .opacity(phase ? 0.55 : 1)
            .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { phase = true } }
            .accessibilityHidden(true)
    }
}

enum FormatStyleHelpers {
    /// W/D/L translated to the reader's language (G/B/M in Turkish, S/U/N in German, ...).
    static func formLetter(_ result: String) -> String {
        switch result {
        case "W": String(localized: "form.win.short", bundle: .module)
        case "D": String(localized: "form.draw.short", bundle: .module)
        case "L": String(localized: "form.loss.short", bundle: .module)
        default: result
        }
    }
}
#endif
