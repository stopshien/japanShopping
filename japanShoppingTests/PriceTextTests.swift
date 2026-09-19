//
//  PriceTextTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

final class PriceTextTests: XCTestCase {

    func testWholeAmountsHaveNoDecimalPoint() {
        XCTAssertEqual(PriceText.amount(206), "206")
        XCTAssertEqual(PriceText.amount(0), "0")
        XCTAssertEqual(PriceText.amount(1580), "1580")
    }

    func testRealCentsAreKept() {
        XCTAssertEqual(PriceText.amount(4995.88), "4995.88")
        XCTAssertEqual(PriceText.amount(2992.1), "2992.1")
    }

    /// 信用卡剩餘額度是浮點相減的結果，可能帶出一長串尾數。
    func testFloatingPointTailIsTrimmed() {
        XCTAssertEqual(PriceText.amount(999.3629999999999), "999.36")
        XCTAssertEqual(PriceText.amount(1008.4879999999999), "1008.49")
    }

    func testThirdDecimalPlaceIsRoundedAway() {
        XCTAssertEqual(PriceText.amount(1988.345), "1988.35")
        XCTAssertEqual(PriceText.amount(1488.344), "1488.34")
    }

    func testNoThousandsSeparator() {
        XCTAssertEqual(PriceText.amount(1234567), "1234567")
    }

    func testNegativeAmountsKeepTheirSign() {
        XCTAssertEqual(PriceText.amount(-42), "-42")
    }

    // MARK: - 首頁的台幣大字與輸入框

    func testTWDHasPrefixAndThousandsSeparator() {
        XCTAssertEqual(PriceText.twd(254), "NT$ 254")
        XCTAssertEqual(PriceText.twd(12345.5), "NT$ 12,345.5")
    }

    func testGroupedInputKeepsWhatTheUserIsTyping() {
        XCTAssertEqual(PriceText.groupedInput("1000"), "1,000")
        XCTAssertEqual(PriceText.groupedInput("1000."), "1,000.", "小數點要留著讓使用者繼續打")
        XCTAssertEqual(PriceText.groupedInput("1234567.05"), "1,234,567.05")
        XCTAssertNil(PriceText.groupedInput(""))
        XCTAssertNil(PriceText.groupedInput("abc"))
    }

    func testSpokenTWDAvoidsTheDollarSign() {
        XCTAssertEqual(PriceText.twdSpoken(1254), "台幣 1,254 元")
    }
}
