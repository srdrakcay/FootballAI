#if os(iOS)
import CoreDomain
import SwiftUI

/// Regional grouping of competitions for the match list: pick a category, then one of its leagues.
/// Known football-data.org codes map directly; anything else (new leagues after a provider plan
/// upgrade, regional competitions) is placed by the competition's area so it still shows up.
enum MatchCategory: String, CaseIterable, Hashable, Identifiable {
    case europeTop, europeOther, cups, americas, asiaPacific, world, other

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .europeTop: "category.europeTop"
        case .europeOther: "category.europeOther"
        case .cups: "category.cups"
        case .americas: "category.americas"
        case .asiaPacific: "category.asiaPacific"
        case .world: "category.world"
        case .other: "category.other"
        }
    }

    private static let europeTopCodes: Set<String> = ["PL", "PD", "SA", "BL1", "FL1"]
    private static let europeOtherCodes: Set<String> = ["DED", "PPL", "ELC", "BL2", "SA2", "FL2", "PD2", "TSL", "SPL", "BJL", "ASL", "SSL", "ESL", "DSL", "ALS"]
    private static let cupCodes: Set<String> = ["CL", "UCL", "EL", "UECL", "ECL", "FAC", "CDR", "DFB", "CIT", "CDF"]
    private static let americasCodes: Set<String> = ["BSA", "CLI", "MLS", "ARG", "LMX", "CSA"]
    private static let asiaPacificCodes: Set<String> = ["KSA", "J1", "ALG", "J2", "KL1", "CSL"]
    private static let worldCodes: Set<String> = ["WC", "EC", "NL", "CNA", "AFC", "ASC", "WCQ"]

    static func of(_ competition: Competition) -> MatchCategory {
        let code = competition.id.rawValue.uppercased()
        if europeTopCodes.contains(code) { return .europeTop }
        if europeOtherCodes.contains(code) { return .europeOther }
        if cupCodes.contains(code) { return .cups }
        if americasCodes.contains(code) { return .americas }
        if asiaPacificCodes.contains(code) { return .asiaPacific }
        if worldCodes.contains(code) { return .world }
        let area = (competition.areaName ?? "").lowercased()
        if area.contains("south america") || area.contains("north america") || area.contains("america") { return .americas }
        if area == "world" || area.contains("international") { return .world }
        if area == "europe" { return .cups }
        return .other
    }
}
#endif
