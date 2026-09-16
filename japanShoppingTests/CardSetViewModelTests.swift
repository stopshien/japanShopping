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
        viewModel.output.didAddCard.sink { didAdd = true }.store(in: &cancellables)

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
    }

    func testAddTappedKeepsExistingCards() {
        repository.storedCards = [Card(name: "舊卡", percent: 2, limit: 1000, feedbackRemaining: 1000)]

        fillValidCard()
        viewModel.input.addTapped()

        XCTAssertEqual(repository.storedCards.map(\.name), ["舊卡", "測試卡"])
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
        viewModel.output.didAddCard.sink { didAdd = true }.store(in: &cancellables)
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
