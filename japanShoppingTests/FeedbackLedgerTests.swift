//
//  FeedbackLedgerTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

// MARK: - 遷移

final class FeedbackLedgerMigrationTests: XCTestCase {

    private var cardRepository: CardRepositoryStub!
    private var ledgerRepository: FeedbackLedgerRepositoryStub!
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    override func setUp() {
        super.setUp()
        cardRepository = CardRepositoryStub()
        ledgerRepository = FeedbackLedgerRepositoryStub()
    }

    override func tearDown() {
        ledgerRepository = nil
        cardRepository = nil
        super.tearDown()
    }

    private func runMigration() {
        FeedbackLedgerMigration.run(cardRepository: cardRepository, ledgerRepository: ledgerRepository, now: now)
    }

    /// 舊版上限 500、剩 499.1，已用的 0.9 要變成一筆明細，剩餘額度不能歸零。
    func testUsedAmountBecomesOneLegacyEntry() {
        let id = UUID()
        let card = Card(name: "舊卡", percent: 3.5, limit: 500, feedbackRemaining: 499.1, id: id)
        cardRepository.storedCards = [card]

        runMigration()

        XCTAssertEqual(ledgerRepository.storedEntries.count, 1)
        XCTAssertEqual(ledgerRepository.storedEntries.first?.cardID, id)
        XCTAssertEqual(ledgerRepository.storedEntries.first?.amount, 0.9)
        XCTAssertEqual(ledgerRepository.storedEntries.first?.date, now)
        XCTAssertNil(ledgerRepository.storedEntries.first?.shoppingItemID)
    }

    func testUnusedCardsGetNoEntry() {
        cardRepository.storedCards = [Card(name: "新卡", percent: 3, limit: 500, feedbackRemaining: 500, id: UUID())]

        runMigration()

        XCTAssertEqual(ledgerRepository.saveCallCount, 0)
    }

    /// 已經有明細的卡片視為遷移過，再跑一次不能重複加。
    func testRunningTwiceAddsTheLegacyEntryOnce() {
        cardRepository.storedCards = [Card(name: "舊卡", percent: 3.5, limit: 500, feedbackRemaining: 400, id: UUID())]

        runMigration()
        runMigration()

        XCTAssertEqual(ledgerRepository.storedEntries.count, 1)
        XCTAssertEqual(ledgerRepository.saveCallCount, 1)
    }

    func testCardsWithoutAnIDAreSkipped() {
        cardRepository.storedCards = [Card(name: "舊卡", percent: 3.5, limit: 500, feedbackRemaining: 400)]

        runMigration()

        XCTAssertTrue(ledgerRepository.storedEntries.isEmpty)
    }

    /// 明細讀不出來時不動任何東西，避免蓋掉既有明細。
    func testNothingIsWrittenWhenTheLedgerCannotBeRead() {
        cardRepository.storedCards = [Card(name: "舊卡", percent: 3.5, limit: 500, feedbackRemaining: 400, id: UUID())]
        ledgerRepository.loadError = StubError.failure

        runMigration()

        XCTAssertEqual(ledgerRepository.saveCallCount, 0)
    }
}

// MARK: - 存檔

final class FileFeedbackLedgerRepositoryTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
        try super.tearDownWithError()
    }

    func testLoadReturnsEmptyWhenTheFileDoesNotExist() throws {
        let repository = FileFeedbackLedgerRepository(fileURL: directory.appendingPathComponent("cardFeedback"))

        XCTAssertEqual(try repository.load(), [])
    }

    func testSaveThenLoadReturnsTheSameEntries() throws {
        let repository = FileFeedbackLedgerRepository(fileURL: directory.appendingPathComponent("cardFeedback"))
        let entries = [
            FeedbackEntry(id: UUID(), cardID: UUID(), date: Date(timeIntervalSince1970: 1_790_000_000),
                          amount: 12.34, shoppingItemID: UUID()),
            FeedbackEntry(id: UUID(), cardID: UUID(), date: Date(timeIntervalSince1970: 1_790_000_100),
                          amount: 0.9, shoppingItemID: nil)
        ]

        try repository.save(entries)

        XCTAssertEqual(try repository.load(), entries)
    }
}
