import CoreDomain
import Foundation

public protocol LocaleProviding: Sendable {
    func current() async -> SupportedLocale
    func set(_ locale: SupportedLocale?) async
}

public actor InMemoryLocaleProvider: LocaleProviding {
    private var selected: SupportedLocale?
    private let systemIdentifier: @Sendable () -> String

    public init(selected: SupportedLocale? = nil, systemIdentifier: @escaping @Sendable () -> String = { Locale.autoupdatingCurrent.identifier }) {
        self.selected = selected; self.systemIdentifier = systemIdentifier
    }

    public func current() -> SupportedLocale { selected ?? SupportedLocale.resolve(identifier: systemIdentifier()) }
    public func set(_ locale: SupportedLocale?) { selected = locale }
}

public enum L10n {
    public static func text(_ key: String, locale: SupportedLocale? = nil) -> String {
        let language = locale?.rawValue ?? Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en"
        let path = Bundle.module.path(forResource: language, ofType: "lproj")
        let bundle = path.flatMap(Bundle.init(path:)) ?? .module
        return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }
}

public struct MatchDateFormatter: Sendable {
    public init() {}
    public func string(from date: Date, locale: SupportedLocale) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: locale.rawValue)))
    }
}
