//
//  CardListViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

final class CardListViewModelTests: XCTestCase {

    private var repository: CardRepositoryStub!
    private var ledgerRepository: FeedbackLedgerRepositoryStub!
    private var viewModel: CardListViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        repository = CardRepositoryStub(storedCards: [
            Card.withPlan(name: "A卡", rate: 3, cap: 1000),
            Card.withPlan(name: "B卡", rate: 5, cap: 2000)
        ])
        ledgerRepository = FeedbackLedgerRepositoryStub()
        viewModel = CardListViewModel(repository: repository, ledgerRepository: ledgerRepository)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        ledgerRepository = nil
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

    /// 這頁最常被回頭查的是剩餘額度，由方案的回饋明細算出。
    func testRemainingIsComputedFromTheLedger() {
        let planID = UUID()
        let card = Card.withPlan(name: "A卡", rate: 3.5, cap: 5000, planID: planID)
        repository.storedCards = [card]
        ledgerRepository.storedEntries = [
            FeedbackEntry(id: UUID(), cardID: card.id!, date: Date(), amount: 4.12, shoppingItemID: UUID(),
                          planID: planID, baseAmount: 4.12, bonusAmount: 0)
        ]
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.first?.percentBadge, "3.5%")
        XCTAssertEqual(items.first?.limitDescription, "上限 5000　剩餘 4995.88")
    }

    func testAnUncappedCardWithABonusShowsBothRates() {
        let bonus = CardPlan.Bonus(rate: 6, cap: 500, label: "指定店家")
        repository.storedCards = [Card.withPlan(name: "熊本熊", rate: 2.5, cap: nil, bonus: bonus)]
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.first?.percentBadge, "2.5%＋6%")
        XCTAssertEqual(items.first?.limitDescription, "加碼上限 500　剩餘 500")
    }

    func testAPeriodicCapNamesItsPeriod() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 12))!
        let planID = UUID()
        var card = Card.withPlan(name: "玉山", rate: 2.5, cap: 1000, planID: planID)
        card.plans?[0].baseCapPeriod = .calendarMonth
        repository.storedCards = [card]
        ledgerRepository.storedEntries = [
            FeedbackEntry(id: UUID(), cardID: card.id!, date: now, amount: 120, shoppingItemID: nil,
                          planID: planID, baseAmount: 120, bonusAmount: 0),
            FeedbackEntry(id: UUID(), cardID: card.id!, date: now.addingTimeInterval(-40 * 86_400), amount: 300,
                          shoppingItemID: nil, planID: planID, baseAmount: 300, bonusAmount: 0)
        ]
        viewModel = CardListViewModel(
            repository: repository, ledgerRepository: ledgerRepository, now: { now }, calendar: calendar
        )
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.first?.limitDescription, "每月上限 1000　本月剩餘 880")
    }

    func testACardWithoutAnyCapSaysSo() {
        repository.storedCards = [Card.withPlan(name: "Richart", rate: 3.3, cap: nil)]
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.first?.limitDescription, "回饋無上限")
    }

    func testASwitchableCardListsItsPlans() {
        let plans = [
            CardPlan(id: UUID(), name: "玩旅刷", baseRate: 3.3, baseCap: nil, bonus: nil, note: ""),
            CardPlan(id: UUID(), name: "假日刷", baseRate: 2, baseCap: nil, bonus: nil, note: "")
        ]
        repository.storedCards = [Card(name: "Richart", percent: 3.3, limit: 0, feedbackRemaining: 0, id: UUID(), plans: plans)]
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.first?.percentBadge, "2 個方案")
        XCTAssertEqual(items.first?.limitDescription, "玩旅刷 3.3%・假日刷 2%")
    }

    func testFinishRemovesTheEntriesOfDeletedCards() {
        let keptID = UUID()
        let deletedID = UUID()
        repository.storedCards = [
            Card.withPlan(name: "A卡", rate: 3, cap: 1000, id: deletedID),
            Card.withPlan(name: "B卡", rate: 5, cap: 2000, id: keptID)
        ]
        ledgerRepository.storedEntries = [
            FeedbackEntry(id: UUID(), cardID: deletedID, date: Date(), amount: 10, shoppingItemID: nil),
            FeedbackEntry(id: UUID(), cardID: keptID, date: Date(), amount: 20, shoppingItemID: nil)
        ]

        viewModel.input.viewDidLoad()
        viewModel.input.deleteCard(at: 0)
        XCTAssertEqual(ledgerRepository.saveCallCount, 0, "按「完成」之前不動明細")

        viewModel.input.finishTapped()

        XCTAssertEqual(ledgerRepository.storedEntries.map(\.cardID), [keptID])
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

    // MARK: - 從這頁新增卡片

    func testCreateTappedRoutes() {
        var routes: [CardListRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.createTapped()

        XCTAssertEqual(routes, [.createCard])
    }

    func testReloadPicksUpACardAddedFromThisScreen() {
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        repository.storedCards.append(Card.withPlan(name: "C卡", rate: 1, cap: 100))
        viewModel.input.reloadAfterCardSaved()

        XCTAssertEqual(items.map(\.name), ["A卡", "B卡", "C卡"])
    }

    /// 刪除要按「完成」才生效，所以去新增卡片再回來時，
    /// 尚未套用的刪除不能被重載沖掉。
    func testReloadKeepsPendingDeletions() {
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.deleteCard(at: 0)
        XCTAssertEqual(items.map(\.name), ["B卡"])

        repository.storedCards.append(Card.withPlan(name: "C卡", rate: 1, cap: 100))
        viewModel.input.reloadAfterCardSaved()

        XCTAssertEqual(items.map(\.name), ["B卡", "C卡"], "A卡的刪除要保留")

        viewModel.input.finishTapped()
        XCTAssertEqual(repository.storedCards.map(\.name), ["B卡", "C卡"])
    }

    func testReloadWithNoNewCardChangesNothing() {
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.deleteCard(at: 0)
        viewModel.input.reloadAfterCardSaved()

        XCTAssertEqual(items.map(\.name), ["B卡"])
    }

    // MARK: - 編輯

    func testSelectingACardRoutesToEditIt() {
        repository.storedCards[0].id = UUID()
        var routes: [CardListRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.cardSelected(at: 0)
        viewModel.input.cardSelected(at: 99)

        XCTAssertEqual(routes, [.editCard(repository.storedCards[0])])
    }

    func testReloadReplacesAnEditedCardInPlace() {
        let id = UUID()
        repository.storedCards[0].id = id
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        repository.storedCards[0] = Card.withPlan(name: "A卡改名", rate: 4, cap: 1000, id: id)
        viewModel.input.reloadAfterCardSaved()

        XCTAssertEqual(items.map(\.name), ["A卡改名", "B卡"], "編輯過的卡片留在原位，不會多一張")
    }

    /// 刪掉一張卡之後，就算它在別處被編輯過，尚未套用的刪除也要保留。
    func testReloadKeepsAPendingDeletionOfAnEditedCard() {
        let id = UUID()
        repository.storedCards[0].id = id
        var items: [CardListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.deleteCard(at: 0)
        repository.storedCards[0] = Card.withPlan(name: "A卡改名", rate: 4, cap: 1000, id: id)
        viewModel.input.reloadAfterCardSaved()

        XCTAssertEqual(items.map(\.name), ["B卡"])
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
