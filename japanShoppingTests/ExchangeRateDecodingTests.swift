//
//  ExchangeRateDecodingTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

/// 鎖定匯率 API 的回應格式與日圓兌台幣的換算方式。
final class ExchangeRateDecodingTests: XCTestCase {

    private let sampleJSON = """
    {
        "result": "success",
        "time_last_update_utc": "Fri, 13 Jun 2025 00:00:01 +0000",
        "base_code": "USD",
        "conversion_rates": {
            "USD": 1,
            "JPY": 157.25,
            "TWD": 32.5
        }
    }
    """.data(using: .utf8)!

    func testDecodesConversionRates() throws {
        let rate = try JSONDecoder().decode(ExchangeRate.self, from: sampleJSON)

        XCTAssertEqual(rate.conversionRates.usd, 1)
        XCTAssertEqual(rate.conversionRates.jpy, 157.25)
        XCTAssertEqual(rate.conversionRates.twd, 32.5)
    }

    func testDecodesUpdateTimestamp() throws {
        let rate = try JSONDecoder().decode(ExchangeRate.self, from: sampleJSON)

        XCTAssertEqual(rate.lastUpdatedUTC, "Fri, 13 Jun 2025 00:00:01 +0000")
    }

    /// 日圓兌台幣是由 TWD / JPY 推導，並取到小數點後四位。
    func testYenToTaiwanDollarRateIsDerivedAndRoundedToFourPlaces() throws {
        let rate = try JSONDecoder().decode(ExchangeRate.self, from: sampleJSON)

        XCTAssertEqual(rate.yenToTaiwanDollar, 0.2067, accuracy: 0.00001)
    }

    /// API 回傳的時間字串必須用 en_US_POSIX 解析，否則在非英文語系裝置上會解析失敗。
    func testUpdateTimestampParsesWithPOSIXLocale() throws {
        let rate = try JSONDecoder().decode(ExchangeRate.self, from: sampleJSON)

        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        XCTAssertNotNil(formatter.date(from: rate.lastUpdatedUTC))
    }
}
