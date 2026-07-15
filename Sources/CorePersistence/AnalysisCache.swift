import CoreDomain
import Foundation

public protocol AnalysisCaching: Sendable {
    func value(for id: AnalysisID, locale: SupportedLocale, now: Date) async -> Analysis?
    func store(_ analysis: Analysis) async throws
    func removeExpired(now: Date) async throws
}

public actor FileAnalysisCache: AnalysisCaching {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL) {
        self.directory = directory
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func value(for id: AnalysisID, locale: SupportedLocale, now: Date) async -> Analysis? {
        let url = fileURL(for: id, locale: locale)
        guard let data = try? Data(contentsOf: url), let analysis = try? decoder.decode(Analysis.self, from: data) else { return nil }
        guard analysis.validUntil > now else { try? FileManager.default.removeItem(at: url); return nil }
        return analysis
    }

    public func store(_ analysis: Analysis) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(analysis).write(to: fileURL(for: analysis.id, locale: analysis.language), options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    public func removeExpired(now: Date) async throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url), let analysis = try? decoder.decode(Analysis.self, from: data), analysis.validUntil > now else {
                try? FileManager.default.removeItem(at: url); continue
            }
        }
    }

    private func fileURL(for id: AnalysisID, locale: SupportedLocale) -> URL {
        let encoded = Data("\(id.rawValue)\u{1F}\(locale.rawValue)".utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
        return directory.appendingPathComponent(encoded).appendingPathExtension("json")
    }
}
