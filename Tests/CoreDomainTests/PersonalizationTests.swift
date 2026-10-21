import CoreDomain
import Foundation
import XCTest

final class PersonalizationTests: XCTestCase {
    func testWalletAvailabilityExcludesReservedCredits() {
        let wallet = CreditWallet(balance: 3, reserved: 2, analysisCreditCost: 1)
        XCTAssertEqual(wallet.available, 1)
        XCTAssertTrue(wallet.canAffordAnalysis)
        XCTAssertFalse(CreditWallet(balance: 1, reserved: 1, analysisCreditCost: 1).canAffordAnalysis)
        XCTAssertEqual(CreditWallet(balance: 1, reserved: 5, analysisCreditCost: 1).reserved, 1)
    }

    func testWalletDecodesServerPayload() throws {
        let json = Data(#"{"balance":5,"reserved":1,"available":4,"analysisCreditCost":2}"#.utf8)
        let wallet = try JSONDecoder().decode(CreditWallet.self, from: json)
        XCTAssertEqual(wallet.available, 4)
        XCTAssertEqual(wallet.analysesAffordable, 2)
    }

    func testProfileDecodingIgnoresUnknownMarketsAndKeepsOne() throws {
        let json = Data(#"{"style":"deep","focusMarkets":["corners","goals"],"competitionIds":["PL"]}"#.utf8)
        let profile = try JSONDecoder().decode(AIProfile.self, from: json)
        XCTAssertEqual(profile.style, .deep)
        XCTAssertEqual(profile.focusMarkets, [.goals])
        XCTAssertEqual(AIProfile(focusMarkets: []).focusMarkets, [.matchResult])
    }

    func testCreditPackageParsesCreditsAndUnitPrice() {
        let package = CreditPackage(id: "footballai_credits_10", title: "10", localizedPrice: "₺169,99", price: Decimal(string: "169.99"))
        XCTAssertEqual(package.credits, 10)
        XCTAssertEqual(package.pricePerCredit, Decimal(string: "16.999"))
        XCTAssertNil(CreditPackage(id: "credits", title: "x", localizedPrice: "1").credits)
    }

    func testUnlockedPayloadDecodes() throws {
        let analysis = Data("""
        {"analysisId":"ana_1","fixtureKey":"football-data:1","generatedAt":"2026-10-21T18:05:00.123Z","validUntil":"2026-10-21T21:59:00Z",
         "markets":{"matchResult":{"homePct":46,"drawPct":29,"awayPct":25},"goals25":{"overPct":54,"underPct":46},"bothTeamsScore":{"yesPct":57,"noPct":43},
         "likelyScores":[{"home":1,"away":1,"pct":12}],"otherScoresPct":88},
         "confidence":{"level":"medium","scorePct":63},"rationale":[{"code":"FORM","evidenceRefs":["sections.recentForm"]}],
         "dataAvailability":{"recentForm":"available"},"limitations":["LINEUPS_UNAVAILABLE"]}
        """.utf8)
        let value = try JSONDecoder().decode(MatchAnalysis.self, from: analysis)
        XCTAssertNotNil(value.generatedDate, "fractional-second timestamps must parse")
        XCTAssertNotNil(value.validUntilDate)
        XCTAssertEqual(value.markets.matchResult.homePct, 46)

        let personal = Data("""
        {"headline":"North City hafif favori","summary":"…","forYou":null,"keyFactors":[{"section":"standings","text":"…"}],
         "watchNote":"İlk 11'ler henüz açıklanmadı.","locale":"de","source":"model","favoriteSide":"home"}
        """.utf8)
        let layer = try JSONDecoder().decode(PersonalAnalysis.self, from: personal)
        XCTAssertEqual(layer.locale, .de)
        XCTAssertEqual(layer.favoriteSide, .home)
        XCTAssertEqual(layer.keyFactors.first?.section, .standings)
    }

    func testHistoryItemKnowsWhenAllOutcomesExist() {
        let base = AnalysisHistoryItem(id: "1", fixtureKey: .init(rawValue: "f"), analysisID: .init(rawValue: "a"), competitionName: "PL", homeTeamName: "A", awayTeamName: "B", kickoffAt: .now, viewedAt: .now, generatedAt: .now, validUntil: .now, homeWinProbability: 40)
        XCTAssertFalse(base.hasFullResult)
        let full = AnalysisHistoryItem(id: "1", fixtureKey: .init(rawValue: "f"), analysisID: .init(rawValue: "a"), competitionName: "PL", homeTeamName: "A", awayTeamName: "B", kickoffAt: .now, viewedAt: .now, generatedAt: .now, validUntil: .now, homeWinProbability: 40, drawProbability: 30, awayWinProbability: 30)
        XCTAssertTrue(full.hasFullResult)
    }
}
