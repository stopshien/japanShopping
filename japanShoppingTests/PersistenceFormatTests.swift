//
//  PersistenceFormatTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

/// 這些測試鎖定 List 與 Card 的存檔格式。
/// 遷移到 MVVM 的過程中，使用者既有的存檔必須仍然讀得回來，
/// 所以任何會讓這些測試失敗的變更，都代表會弄壞既有使用者的資料。
final class PersistenceFormatTests: XCTestCase {

    // MARK: - List

    func testListSurvivesPropertyListRoundTrip() throws {
        let original = List(
            productName: "抹茶巧克力",
            price: 1080,
            payType: "現金",
            taxState: "含稅",
            photoURL: "A1B2C3D4"
        )

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.productName, original.productName)
        XCTAssertEqual(decoded.price, original.price)
        XCTAssertEqual(decoded.payType, original.payType)
        XCTAssertEqual(decoded.taxState, original.taxState)
        XCTAssertEqual(decoded.photoURL, original.photoURL)
    }

    func testListWithoutPhotoDecodesWithNilPhotoURL() throws {
        let original = List(productName: "咖啡", price: 450, payType: "信用卡", taxState: "未稅")

        let decoded = try roundTrip(original)

        XCTAssertNil(decoded.photoURL)
    }

    func testListArraySurvivesPropertyListRoundTrip() throws {
        let original = [
            List(productName: "第一項", price: 100, payType: "現金", taxState: "含稅"),
            List(productName: "第二項", price: 200, payType: "信用卡", taxState: "未稅")
        ]

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded.map(\.productName), ["第一項", "第二項"])
    }

    // MARK: - Card

    func testCardSurvivesPropertyListRoundTrip() throws {
        let original = Card(name: "測試卡", percent: 3.5, limit: 5000, feedbackMoney: 120, feedbackRemaining: 4880)

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.percent, original.percent)
        XCTAssertEqual(decoded.limit, original.limit)
        XCTAssertEqual(decoded.feedbackMoney, original.feedbackMoney)
        XCTAssertEqual(decoded.feedbackRemaining, original.feedbackRemaining)
    }

    /// 新建的卡片在 CardSetViewController 只會帶入 limit 作為 feedbackRemaining 的初始值，
    /// feedbackMoney 則沿用預設值 0。
    func testNewCardDefaultsFeedbackMoneyToZero() throws {
        let original = Card(name: "新卡", percent: 2, limit: 3000, feedbackRemaining: 3000)

        let decoded = try roundTrip(original)

        XCTAssertEqual(decoded.feedbackMoney, 0)
        XCTAssertEqual(decoded.feedbackRemaining, 3000)
    }

    // MARK: - Helpers

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let data = try PropertyListEncoder().encode(value)
        return try PropertyListDecoder().decode(T.self, from: data)
    }
}
