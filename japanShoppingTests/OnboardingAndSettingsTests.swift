//
//  OnboardingAndSettingsTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

// MARK: - 引導流程第二步

final class CurrencySelectionViewModelTests: XCTestCase {

    private var repository: UserProfileRepositoryStub!
    private var viewModel: CurrencySelectionViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        repository = UserProfileRepositoryStub()
        viewModel = CurrencySelectionViewModel(name: "Angus", repository: repository)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        repository = nil
        super.tearDown()
    }

    func testDefaultsToJapaneseYen() {
        var currency: Currency?
        viewModel.output.selectedCurrency.sink { currency = $0 }.store(in: &cancellables)

        XCTAssertEqual(currency, .japaneseYen)
    }

    /// 說明文字要讓使用者知道選了會套用什麼稅率。
    func testDescriptionMentionsBothJapaneseRates() {
        var text: String?
        viewModel.output.currencyDescription.sink { text = $0 }.store(in: &cancellables)

        XCTAssertEqual(text, "稅率：一般 10%、食品 8%，可於每筆消費切換")
    }

    func testDescriptionForSingleRateCurrency() {
        var text: String?
        viewModel.output.currencyDescription.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.currencySelected(.koreanWon)

        XCTAssertEqual(text, "稅率：10%")
    }

    /// 名字由上一步帶入，這一步才寫入完整設定。
    func testConfirmSavesTheCompleteProfile() {
        var didFinish = false
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)

        viewModel.input.currencySelected(.koreanWon)
        viewModel.input.confirmTapped()

        XCTAssertTrue(didFinish)
        XCTAssertEqual(repository.storedProfile, UserProfile(name: "Angus", currency: .koreanWon))
    }

    /// 中途離開不會留下只有名字的半套設定。
    func testNothingIsSavedBeforeConfirming() {
        viewModel.input.currencySelected(.koreanWon)

        XCTAssertNil(repository.storedProfile)
        XCTAssertEqual(repository.saveCallCount, 0)
    }

    func testSaveFailureReportsErrorAndDoesNotFinish() {
        repository.saveError = StubError.failure
        var didFinish = false
        var message: String?
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.confirmTapped()

        XCTAssertFalse(didFinish)
        XCTAssertEqual(message, "設定儲存失敗，請再試一次")
    }
}

// MARK: - 設定頁

final class SettingsViewModelTests: XCTestCase {

    private var repository: UserProfileRepositoryStub!
    private var viewModel: SettingsViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        repository = UserProfileRepositoryStub(
            storedProfile: UserProfile(name: "Angus", currency: .japaneseYen)
        )
        viewModel = SettingsViewModel(repository: repository)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        repository = nil
        super.tearDown()
    }

    func testViewDidLoadShowsTheStoredSettings() {
        var name: String?
        var currency: Currency?
        viewModel.output.name.sink { name = $0 }.store(in: &cancellables)
        viewModel.output.selectedCurrency.sink { currency = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(name, "Angus")
        XCTAssertEqual(currency, .japaneseYen)
    }

    func testChangingCurrencyIsSaved() {
        viewModel.input.viewDidLoad()
        viewModel.input.currencySelected(.koreanWon)
        viewModel.input.saveTapped()

        XCTAssertEqual(repository.storedProfile?.currency, .koreanWon)
        XCTAssertEqual(repository.storedProfile?.name, "Angus", "只改幣別不該動到稱呼")
    }

    func testChangingNameIsSaved() {
        viewModel.input.viewDidLoad()
        viewModel.input.nameChanged("庭鋒")
        viewModel.input.saveTapped()

        XCTAssertEqual(repository.storedProfile?.name, "庭鋒")
        XCTAssertEqual(repository.storedProfile?.currency, .japaneseYen, "只改稱呼不該動到幣別")
    }

    func testEmptyNameDisablesSave() {
        var isEnabled: Bool?
        viewModel.output.isSaveEnabled.sink { isEnabled = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        XCTAssertEqual(isEnabled, true)

        viewModel.input.nameChanged("   ")
        XCTAssertEqual(isEnabled, false)
    }

    func testSaveIsIgnoredWithoutAName() {
        viewModel.input.viewDidLoad()
        viewModel.input.nameChanged("")
        viewModel.input.saveTapped()

        XCTAssertEqual(repository.storedProfile?.name, "Angus", "未儲存，原值不變")
    }
}
