//
//  FileCardRepositoryTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

final class FileCardRepositoryTests: XCTestCase {

    private var fileURL: URL!
    private var repository: FileCardRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("cards")
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        repository = FileCardRepository(fileURL: fileURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        repository = nil
        fileURL = nil
        try super.tearDownWithError()
    }

    func testLoadReturnsEmptyArrayWhenFileDoesNotExist() throws {
        XCTAssertEqual(try repository.load(), [])
    }

    func testSaveThenLoadReturnsTheSameCards() throws {
        let cards = [
            Card(name: "A卡", percent: 3, limit: 1000, feedbackMoney: 30, feedbackRemaining: 970),
            Card(name: "B卡", percent: 5, limit: 2000, feedbackRemaining: 2000)
        ]

        try repository.save(cards)

        XCTAssertEqual(try repository.load(), cards)
    }

    /// 遷移前是用 PropertyListEncoder 寫入 Documents 下的 "cards"。
    /// 這個測試確保新的 repository 仍讀得懂那個格式。
    func testLoadReadsFileWrittenByTheLegacyFormat() throws {
        let legacyCards = [Card(name: "舊卡", percent: 2.5, limit: 800, feedbackMoney: 20, feedbackRemaining: 780)]
        let data = try PropertyListEncoder().encode(legacyCards)
        try data.write(to: fileURL)

        XCTAssertEqual(try repository.load(), legacyCards)
    }
}
