//
//  CardSetViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

final class CardSetViewModelTests: XCTestCase {

    private var repository: CardRepositoryStub!
    private var viewModel: CardSetViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        repository = CardRepositoryStub()
        viewModel = CardSetViewModel(repository: repository)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        repository = nil
        super.tearDown()
    }

    // MARK: - 新增按鈕啟用條件

    func testAddIsDisabledUntilAllThreeFieldsAreFilled() {
        var states: [Bool] = []
        viewModel.output.isAddEnabled.sink { states.append($0) }.store(in: &cancellables)

        viewModel.input.nameChanged("測試卡")
        viewModel.input.percentChanged("3")

        XCTAssertEqual(states.last, false, "只填兩個欄位時不應啟用")

        viewModel.input.limitChanged("5000")

        XCTAssertEqual(states.last, true, "三個欄位都填了才啟用")
    }

    func testAddIsDisabledWhenFieldIsOnlyWhitespace() {
        viewModel.input.nameChanged("   ")
        viewModel.input.percentChanged("3")
        viewModel.input.limitChanged("5000")

        var isEnabled = true
        viewModel.output.isAddEnabled.sink { isEnabled = $0 }.store(in: &cancellables)

        XCTAssertFalse(isEnabled)
    }

    // MARK: - 新增成功

    func testAddTappedAppendsCardWithRemainingEqualToLimit() {
        var didAdd = false
        viewModel.output.didSave.sink { didAdd = true }.store(in: &cancellables)

        fillValidCard()
        viewModel.input.addTapped()

        XCTAssertTrue(didAdd)
        XCTAssertEqual(repository.storedCards.count, 1)

        let card = try? XCTUnwrap(repository.storedCards.first)
        XCTAssertEqual(card?.name, "測試卡")
        XCTAssertEqual(card?.percent, 3.5)
        XCTAssertEqual(card?.limit, 5000)
        XCTAssertEqual(card?.feedbackRemaining, 5000, "新卡的剩餘回饋額度應等於上限")
        XCTAssertEqual(card?.feedbackMoney, 0, "新卡尚未產生回饋金額")
        XCTAssertNotNil(card?.id, "新卡一建立就有識別碼")
    }

    func testAddTappedKeepsExistingCards() {
        repository.storedCards = [Card(name: "舊卡", percent: 2, limit: 1000, feedbackRemaining: 1000)]

        fillValidCard()
        viewModel.input.addTapped()

        XCTAssertEqual(repository.storedCards.map(\.name), ["舊卡", "測試卡"])
    }

    // MARK: - 編輯

    private func makeEditingViewModel(for card: Card) -> CardSetViewModel {
        CardSetViewModel(editingCard: card, repository: repository)
    }

    func testEditingPrefillsTheFieldsAndIsReadyToSave() {
        let card = Card(name: "玉山", percent: 3.5, limit: 500, feedbackRemaining: 200, id: UUID())
        viewModel = makeEditingViewModel(for: card)
        var isEnabled = false
        viewModel.output.isAddEnabled.sink { isEnabled = $0 }.store(in: &cancellables)

        XCTAssertEqual(viewModel.output.prefill, CardSetPrefill(name: "玉山", percent: "3.5", limit: "500"))
        XCTAssertEqual(viewModel.output.title, "編輯信用卡")
        XCTAssertEqual(viewModel.output.confirmTitle, "儲存")
        XCTAssertTrue(isEnabled)
    }

    func testAddingHasNoPrefill() {
        XCTAssertNil(viewModel.output.prefill)
        XCTAssertEqual(viewModel.output.title, "新增信用卡")
    }

    /// 已用掉 300，上限改成 1000 後剩 700；id 不變，其他卡不受影響。
    func testEditReplacesTheCardAndKeepsTheUsedAmount() {
        let id = UUID()
        let card = Card(name: "玉山", percent: 3.5, limit: 500, feedbackRemaining: 200, id: id)
        let other = Card(name: "台新", percent: 3.3, limit: 0, feedbackRemaining: 0, id: UUID())
        repository.storedCards = [card, other]
        viewModel = makeEditingViewModel(for: card)
        var didSave = false
        viewModel.output.didSave.sink { didSave = true }.store(in: &cancellables)

        viewModel.input.nameChanged("玉山熊本熊")
        viewModel.input.percentChanged("8.5")
        viewModel.input.limitChanged("1000")
        viewModel.input.addTapped()

        XCTAssertTrue(didSave)
        XCTAssertEqual(repository.storedCards.count, 2)
        let edited = repository.storedCards[0]
        XCTAssertEqual(edited.id, id)
        XCTAssertEqual(edited.name, "玉山熊本熊")
        XCTAssertEqual(edited.percent, 8.5)
        XCTAssertEqual(edited.limit, 1000)
        XCTAssertEqual(edited.feedbackRemaining, 700)
        XCTAssertEqual(repository.storedCards[1], other)
    }

    func testLoweringTheLimitBelowTheUsedAmountLeavesZero() {
        let card = Card(name: "玉山", percent: 3.5, limit: 500, feedbackRemaining: 200, id: UUID())
        repository.storedCards = [card]
        viewModel = makeEditingViewModel(for: card)

        viewModel.input.limitChanged("100")
        viewModel.input.addTapped()

        XCTAssertEqual(repository.storedCards.first?.feedbackRemaining, 0)
    }

    func testEditingACardThatNoLongerExistsReportsAnError() {
        let card = Card(name: "玉山", percent: 3.5, limit: 500, feedbackRemaining: 200, id: UUID())
        repository.storedCards = []
        viewModel = makeEditingViewModel(for: card)
        var message: String?
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.addTapped()

        XCTAssertEqual(message, "找不到這張信用卡，可能已被刪除")
        XCTAssertEqual(repository.saveCallCount, 0)
    }

    // MARK: - 驗證與錯誤

    /// 遷移前這裡是 Double(text)! ，非數字輸入會直接崩潰。
    /// 現在改為回報錯誤訊息，這是本次遷移唯一刻意的行為變更。
    func testNonNumericPercentReportsErrorInsteadOfCrashing() {
        var message: String?
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.nameChanged("測試卡")
        viewModel.input.percentChanged("三趴")
        viewModel.input.limitChanged("5000")
        viewModel.input.addTapped()

        XCTAssertEqual(message, "回饋趴數請輸入數字")
        XCTAssertTrue(repository.storedCards.isEmpty)
    }

    func testNonNumericLimitReportsError() {
        var message: String?
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.nameChanged("測試卡")
        viewModel.input.percentChanged("3")
        viewModel.input.limitChanged("五千")
        viewModel.input.addTapped()

        XCTAssertEqual(message, "回饋上限請輸入數字")
        XCTAssertTrue(repository.storedCards.isEmpty)
    }

    func testAddTappedDoesNothingWhenFieldsAreIncomplete() {
        viewModel.input.nameChanged("測試卡")
        viewModel.input.addTapped()

        XCTAssertEqual(repository.saveCallCount, 0)
    }

    func testSaveFailureReportsErrorAndDoesNotFinish() {
        repository.saveError = StubError.failure
        var didAdd = false
        var message: String?
        viewModel.output.didSave.sink { didAdd = true }.store(in: &cancellables)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        fillValidCard()
        viewModel.input.addTapped()

        XCTAssertFalse(didAdd)
        XCTAssertEqual(message, "信用卡儲存失敗，請再試一次")
    }

    // MARK: - Helpers

    private func fillValidCard() {
        viewModel.input.nameChanged("測試卡")
        viewModel.input.percentChanged("3.5")
        viewModel.input.limitChanged("5000")
    }
}
