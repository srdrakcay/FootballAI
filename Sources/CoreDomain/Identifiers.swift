import Foundation

public struct FixtureKey: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

public struct AnalysisID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct AnalysisRequestID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct SnapshotID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct CompetitionID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct TeamID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public enum SupportedLocale: String, Codable, CaseIterable, Sendable {
    case tr, en, de, es, fr

    public static func resolve(identifier: String) -> SupportedLocale {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        if let exact = Self(rawValue: normalized) { return exact }
        let base = normalized.split(separator: "-").first.map(String.init) ?? "en"
        return Self(rawValue: base) ?? .en
    }
}
