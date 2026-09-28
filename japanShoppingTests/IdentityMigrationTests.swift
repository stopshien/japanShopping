//
//  IdentityMigrationTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

final class IdentityMigrationTests: XCTestCase {

    private var cardRepository: CardRepositoryStub!
    private var tripRepository: TripRepositoryStub!
    private var contentStore: TripContentStoreStub!
    private var trip: Trip!

    override func setUp() {
        super.setUp()
        trip = Trip(name: "東京", currency: .japaneseYen)
        cardRepository = CardRepositoryStub()
        tripRepository = TripRepositoryStub(trips: [trip], currentTripID: trip.id)
        contentStore = TripContentStoreStub()
    }

    override func tearDown() {
        contentStore = nil
        tripRepository = nil
        cardRepository = nil
        trip = nil
        super.tearDown()
    }

    private func runMigration() {
        IdentityMigration.run(
            cardRepository: cardRepository,
            tripRepository: tripRepository,
            tripContentStore: contentStore
        )
    }

    private var listRepository: ShoppingListRepositoryStub {
        contentStore.shoppingListRepository(for: trip.id) as! ShoppingListRepositoryStub
    }

    func testCardsWithoutAnIDGetOneAndExistingIDsAreKept() {
        let existing = UUID()
        cardRepository.storedCards = [
            Card(name: "舊卡", percent: 3, limit: 100, feedbackRemaining: 40),
            Card(name: "新卡", percent: 2, limit: 50, feedbackRemaining: 50, id: existing)
        ]

        runMigration()

        XCTAssertNotNil(cardRepository.storedCards[0].id)
        XCTAssertEqual(cardRepository.storedCards[0].feedbackRemaining, 40, "只補 id，其他欄位不變")
        XCTAssertEqual(cardRepository.storedCards[1].id, existing)
    }

    func testShoppingItemsInEveryTripGetAnID() {
        listRepository.storedItems = [
            ShoppingItem(productName: "抹茶", price: 100, payType: "現金", taxState: "含稅")
        ]

        runMigration()

        XCTAssertNotNil(listRepository.storedItems.first?.id)
        XCTAssertEqual(listRepository.storedItems.first?.productName, "抹茶")
    }

    /// 已遷移過的資料不重寫，id 也不會每次啟動都換掉。
    func testNothingIsWrittenWhenEverythingAlreadyHasAnID() {
        cardRepository.storedCards = [Card(name: "卡", percent: 3, limit: 100, feedbackRemaining: 100, id: UUID())]
        var item = ShoppingItem(productName: "抹茶", price: 100, payType: "現金", taxState: "含稅")
        item.id = UUID()
        listRepository.storedItems = [item]

        runMigration()

        XCTAssertEqual(cardRepository.saveCallCount, 0)
        XCTAssertEqual(listRepository.saveCallCount, 0)
    }

    func testRunningTwiceKeepsTheFirstIDs() {
        cardRepository.storedCards = [Card(name: "舊卡", percent: 3, limit: 100, feedbackRemaining: 100)]

        runMigration()
        let firstID = cardRepository.storedCards[0].id
        runMigration()

        XCTAssertEqual(cardRepository.storedCards[0].id, firstID)
    }
}
