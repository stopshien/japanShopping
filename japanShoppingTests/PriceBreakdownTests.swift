//
//  PriceBreakdownTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

final class PriceBreakdownTests: XCTestCase {

    // MARK: - 日幣（10%）

    func testUntaxedModeDerivesTheTaxedPrice() {
        let breakdown = PriceBreakdown(amount: 1000, rate: 0.2, mode: .excludingTax,
                                       taxMultiplier: Currency.japaneseYen.taxMultiplier(for: .standard))

        XCTAssertEqual(breakdown.untaxed, 200)
        XCTAssertEqual(breakdown.taxed, 220)
    }

    func testTaxedModeDerivesTheUntaxedPrice() {
        let breakdown = PriceBreakdown(amount: 1100, rate: 0.2, mode: .includingTax,
                                       taxMultiplier: Currency.japaneseYen.taxMultiplier(for: .standard))

        XCTAssertEqual(breakdown.taxed, 220)
        XCTAssertEqual(breakdown.untaxed, 200)
    }

    // MARK: - 韓幣（10%）

    func testKoreanWonUsesTenPercentTax() {
        let breakdown = PriceBreakdown(amount: 10000, rate: 0.0235, mode: .excludingTax,
                                       taxMultiplier: Currency.koreanWon.taxMultiplier(for: .standard))

        // 10000 * 0.0235 = 235，含稅 235 * 1.1 = 258.5 → 259
        XCTAssertEqual(breakdown.untaxed, 235)
        XCTAssertEqual(breakdown.taxed, 259)
    }

    func testKoreanWonTaxedModeDerivesTheUntaxedPrice() {
        let breakdown = PriceBreakdown(amount: 10000, rate: 0.022, mode: .includingTax,
                                       taxMultiplier: Currency.koreanWon.taxMultiplier(for: .standard))

        // 10000 * 0.022 = 220（含稅），未稅 220 / 1.1 = 200
        XCTAssertEqual(breakdown.taxed, 220)
        XCTAssertEqual(breakdown.untaxed, 200)
    }

    // MARK: - 共通

    func testBothPricesAreRoundedToWholeDollars() {
        let breakdown = PriceBreakdown(amount: 999, rate: 0.2055, mode: .excludingTax,
                                       taxMultiplier: Currency.japaneseYen.taxMultiplier(for: .standard))

        XCTAssertEqual(breakdown.untaxed, breakdown.untaxed.rounded())
        XCTAssertEqual(breakdown.taxed, breakdown.taxed.rounded())
    }

    // MARK: - 稅率表

    func testJapanHasTwoRates() {
        XCTAssertEqual(Currency.japaneseYen.taxMultiplier(for: .standard), 1.1)
        XCTAssertEqual(Currency.japaneseYen.taxMultiplier(for: .reducedFood), 1.08)
        XCTAssertTrue(Currency.japaneseYen.hasReducedTaxRate)
    }

    /// 韓國加值稅為單一稅率，選商品類別沒有意義，畫面上會隱藏。
    func testKoreaHasASingleRate() {
        XCTAssertEqual(Currency.koreanWon.taxMultiplier(for: .standard), 1.1)
        XCTAssertEqual(Currency.koreanWon.taxMultiplier(for: .reducedFood), 1.1)
        XCTAssertFalse(Currency.koreanWon.hasReducedTaxRate)
    }

    func testTaxPercentIsDerivedFromTheMultiplier() {
        XCTAssertEqual(Currency.japaneseYen.taxPercent(for: .standard), 10)
        XCTAssertEqual(Currency.japaneseYen.taxPercent(for: .reducedFood), 8)
    }

    func testFoodUsesTheReducedRate() {
        let breakdown = PriceBreakdown(amount: 1000, rate: 0.2, mode: .excludingTax,
                                       taxMultiplier: Currency.japaneseYen.taxMultiplier(for: .reducedFood))

        // 1000 * 0.2 = 200，含稅 200 * 1.08 = 216
        XCTAssertEqual(breakdown.untaxed, 200)
        XCTAssertEqual(breakdown.taxed, 216)
    }

    /// 免稅退稅是以未稅價計算，選錯稅率會讓反推的未稅價失準。
    func testReducedRateChangesTheDerivedUntaxedPrice() {
        let standard = PriceBreakdown(amount: 1080, rate: 1, mode: .includingTax,
                                      taxMultiplier: Currency.japaneseYen.taxMultiplier(for: .standard))
        let food = PriceBreakdown(amount: 1080, rate: 1, mode: .includingTax,
                                  taxMultiplier: Currency.japaneseYen.taxMultiplier(for: .reducedFood))

        XCTAssertEqual(standard.untaxed, 982)   // 1080 / 1.10
        XCTAssertEqual(food.untaxed, 1000)      // 1080 / 1.08
    }
}
