//
//  PriceBreakdownTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

final class PriceBreakdownTests: XCTestCase {

    func testUntaxedModeDerivesTheTaxedPrice() {
        let breakdown = PriceBreakdown(yen: 1000, rate: 0.2, mode: .excludingTax)

        XCTAssertEqual(breakdown.untaxed, 200)
        XCTAssertEqual(breakdown.taxed, 216)
    }

    func testTaxedModeDerivesTheUntaxedPrice() {
        let breakdown = PriceBreakdown(yen: 1080, rate: 0.2, mode: .includingTax)

        XCTAssertEqual(breakdown.taxed, 216)
        XCTAssertEqual(breakdown.untaxed, 200)
    }

    func testBothPricesAreRoundedToWholeDollars() {
        let breakdown = PriceBreakdown(yen: 999, rate: 0.2055, mode: .excludingTax)

        XCTAssertEqual(breakdown.untaxed, breakdown.untaxed.rounded())
        XCTAssertEqual(breakdown.taxed, breakdown.taxed.rounded())
    }
}
