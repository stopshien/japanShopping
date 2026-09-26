//
//  ExchangeRateDecodingTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

/// 鎖定匯率 API（免金鑰端點）的回應格式與日圓兌台幣的換算方式。
final class ExchangeRateDecodingTests: XCTestCase {

    private let sampleJSON = """
    {
        "result": "success",
        "time_last_update_utc": "Fri, 13 Jun 2025 00:00:01 +0000",
        "base_code": "USD",
        "rates": {
            "USD": 1,
            "JPY": 157.25,
            "TWD": 32.5,
            "KRW": 1380.0
        }
    }
    """.data(using: .utf8)!

    func testDecodesConversionRates() throws {
        let rate = try JSONDecoder().decode(ExchangeRate.self, from: sampleJSON)

        XCTAssertEqual(rate.conversionRates.usd, 1)
        XCTAssertEqual(rate.conversionRates.jpy, 157.25)
        XCTAssertEqual(rate.conversionRates.twd, 32.5)
        XCTAssertEqual(rate.conversionRates.krw, 1380)
    }

    func testDecodesUpdateTimestamp() throws {
        let rate = try JSONDecoder().decode(ExchangeRate.self, from: sampleJSON)

        XCTAssertEqual(rate.lastUpdatedUTC, "Fri, 13 Jun 2025 00:00:01 +0000")
    }

    /// 日圓兌台幣由 TWD / JPY 推導，取 4 位有效數字。
    func testYenRateIsDerivedFromTaiwanDollarOverYen() throws {
        let rate = try JSONDecoder().decode(ExchangeRate.self, from: sampleJSON)

        XCTAssertEqual(rate.rateToTaiwanDollar(for: .japaneseYen), 0.2067, accuracy: 0.0000001)
    }

    /// 韓元匯率數量級比日圓小一位，取 4 位有效數字才不會損失精度。
    /// 若沿用「小數第 4 位」，這裡會變成 0.0236，誤差 0.2%。
    func testWonRateKeepsFourSignificantDigits() throws {
        let rate = try JSONDecoder().decode(ExchangeRate.self, from: sampleJSON)

        XCTAssertEqual(rate.rateToTaiwanDollar(for: .koreanWon), 0.02355, accuracy: 0.0000001)
    }

    func testZeroForeignRateDoesNotProduceInfinity() throws {
        let rate = ExchangeRate(
            lastUpdatedUTC: "Fri, 13 Jun 2025 00:00:01 +0000",
            conversionRates: ConversionRates(usd: 1, jpy: 0, twd: 32.5, krw: 0)
        )

        XCTAssertEqual(rate.rateToTaiwanDollar(for: .japaneseYen), 0)
        XCTAssertEqual(rate.rateToTaiwanDollar(for: .koreanWon), 0)
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
