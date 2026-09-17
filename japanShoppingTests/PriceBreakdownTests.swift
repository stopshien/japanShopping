//
//  PriceBreakdownTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

final class PriceBreakdownTests: XCTestCase {

    // MARK: - 日幣（8%）

    func testUntaxedModeDerivesTheTaxedPrice() {
        let breakdown = PriceBreakdown(amount: 1000, rate: 0.2, mode: .excludingTax,
                                       taxMultiplier: Currency.japaneseYen.taxMultiplier)

        XCTAssertEqual(breakdown.untaxed, 200)
        XCTAssertEqual(breakdown.taxed, 216)
    }

    func testTaxedModeDerivesTheUntaxedPrice() {
        let breakdown = PriceBreakdown(amount: 1080, rate: 0.2, mode: .includingTax,
                                       taxMultiplier: Currency.japaneseYen.taxMultiplier)

        XCTAssertEqual(breakdown.taxed, 216)
        XCTAssertEqual(breakdown.untaxed, 200)
    }

    // MARK: - 韓幣（10%）

    func testKoreanWonUsesTenPercentTax() {
        let breakdown = PriceBreakdown(amount: 10000, rate: 0.0235, mode: .excludingTax,
                                       taxMultiplier: Currency.koreanWon.taxMultiplier)

        // 10000 * 0.0235 = 235，含稅 235 * 1.1 = 258.5 → 259
        XCTAssertEqual(breakdown.untaxed, 235)
        XCTAssertEqual(breakdown.taxed, 259)
    }

    func testKoreanWonTaxedModeDerivesTheUntaxedPrice() {
        let breakdown = PriceBreakdown(amount: 10000, rate: 0.022, mode: .includingTax,
                                       taxMultiplier: Currency.koreanWon.taxMultiplier)

        // 10000 * 0.022 = 220（含稅），未稅 220 / 1.1 = 200
        XCTAssertEqual(breakdown.taxed, 220)
        XCTAssertEqual(breakdown.untaxed, 200)
    }

    // MARK: - 共通

    func testBothPricesAreRoundedToWholeDollars() {
        let breakdown = PriceBreakdown(amount: 999, rate: 0.2055, mode: .excludingTax,
                                       taxMultiplier: Currency.japaneseYen.taxMultiplier)

        XCTAssertEqual(breakdown.untaxed, breakdown.untaxed.rounded())
        XCTAssertEqual(breakdown.taxed, breakdown.taxed.rounded())
    }

    func testTaxMultipliersFollowTheCountry() {
        XCTAssertEqual(Currency.japaneseYen.taxMultiplier, 1.08)
        XCTAssertEqual(Currency.koreanWon.taxMultiplier, 1.1)
    }
}
