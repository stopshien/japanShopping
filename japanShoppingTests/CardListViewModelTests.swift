//
//  CardListViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

final class CardListViewModelTests: XCTestCase {

    private var repository: CardRepositoryStub!
    private var viewModel: CardListViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        repository = CardRepositoryStub(storedCards: [
            Card(name: "A卡", percent: 3, limit: 1000, feedbackRemaining: 1000),
            Card(name: "B卡", percent: 5, limit: 2000, feedbackRemaining: 2000)
        ])
        viewModel = CardListViewModel(repository: repository)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        repository = nil
        super.tearDown()
    }

    func testViewDidLoadPublishesFormattedItems() {
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.name, "A卡")
        XCTAssertEqual(items.first?.percentBadge, "3%")
        XCTAssertEqual(items.first?.limitDescription, "上限 1000　剩餘 1000")
    }

    /// 這頁最常被回頭查的是剩餘額度，因此必須顯示實際剩餘而非上限。
    func testLimitDescriptionShowsTheRemainingBalance() {
        repository.storedCards = [
            Card(name: "A卡", percent: 3.5, limit: 5000, feedbackMoney: 4.12, feedbackRemaining: 4995.88)
        ]
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.first?.percentBadge, "3.5%")
        XCTAssertEqual(items.first?.limitDescription, "上限 5000　剩餘 4995.88")
    }

    func testDeleteRemovesItemFromTheList() {
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.deleteCard(at: 0)

        XCTAssertEqual(items.map(\.name), ["B卡"])
    }

    /// 刪除不會立即寫檔，誤刪時直接返回即可放棄變更。
    func testDeleteDoesNotPersistUntilFinishIsTapped() {
        viewModel.input.viewDidLoad()
        viewModel.input.deleteCard(at: 0)

        XCTAssertEqual(repository.saveCallCount, 0)
        XCTAssertEqual(repository.storedCards.count, 2, "尚未按下完成，存檔不應變動")

        viewModel.input.finishTapped()

        XCTAssertEqual(repository.saveCallCount, 1)
        XCTAssertEqual(repository.storedCards.map(\.name), ["B卡"])
    }

    func testDeleteOutOfRangeIndexIsIgnored() {
        viewModel.input.viewDidLoad()

        viewModel.input.deleteCard(at: 99)
        viewModel.input.deleteCard(at: -1)

        viewModel.input.finishTapped()
        XCTAssertEqual(repository.storedCards.count, 2)
    }

    func testFinishPublishesDidFinish() {
        var didFinish = false
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.finishTapped()

        XCTAssertTrue(didFinish)
    }

    func testLoadFailureReportsErrorAndShowsEmptyList() {
        repository.loadError = StubError.failure
        var message: String?
        var items: [CardListItem] = []
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(message, "信用卡資料讀取失敗")
        XCTAssertTrue(items.isEmpty)
    }

    func testSaveFailureReportsErrorAndDoesNotFinish() {
        repository.saveError = StubError.failure
        var didFinish = false
        var message: String?
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.finishTapped()

        XCTAssertFalse(didFinish)
        XCTAssertEqual(message, "信用卡儲存失敗，請再試一次")
    }
}
