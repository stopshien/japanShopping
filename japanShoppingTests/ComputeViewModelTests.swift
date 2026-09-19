//
//  ComputeViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

private final class ExchangeRateServiceStub: ExchangeRateService {

    var result: Result<ExchangeRate, Error>

    /// jpy / krw 都設為 1，讓 TWD 的值直接等於該幣別的匯率，測試好讀。
    init(yenRate: Double = 0.2, wonRate: Double = 0.2) {
        self.result = .success(
            ExchangeRate(
                lastUpdatedUTC: "Fri, 13 Jun 2025 00:00:01 +0000",
                conversionRates: ConversionRates(usd: 1, jpy: 1 / yenRate, twd: 1, krw: 1 / wonRate)
            )
        )
    }

    func latestRate() -> AnyPublisher<ExchangeRate, Error> {
        result.publisher.eraseToAnyPublisher()
    }
}

private extension ComputeResultDisplay {
    /// 測試用：把大字與補充合成一行比對，沒有結果時就是提示文字。
    var summary: String {
        isActionable ? "\(secondaryDescription)｜\(primaryAmount)" : hint
    }
}

final class ComputeViewModelTests: XCTestCase {

    private var service: ExchangeRateServiceStub!
    private var tripRepository: TripRepositoryStub!
    private var viewModel: ComputeViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        service = ExchangeRateServiceStub(yenRate: 0.2, wonRate: 0.025)
        tripRepository = TripRepositoryStub(trips: [yenTrip], currentTripID: yenTrip.id)
        viewModel = makeViewModel()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        tripRepository = nil
        service = nil
        super.tearDown()
    }

    private let yenTrip = Trip(name: "日本", currency: .japaneseYen)
    private let wonTrip = Trip(name: "韓國", currency: .koreanWon)

    private func makeViewModel() -> ComputeViewModel {
        ComputeViewModel(service: service, tripRepository: tripRepository)
    }

    /// 切換到另一個專案。
    private func switchToWonTrip() {
        tripRepository.trips = [wonTrip]
        tripRepository.currentTripID = wonTrip.id
    }

    /// ViewModel 以 receive(on: DispatchQueue.main) 派送匯率結果，
    /// 測試必須讓 main queue 跑完一輪才看得到值。
    private func waitForMainQueue() {
        let expectation = expectation(description: "main queue drained")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - 匯率載入

    func testViewDidLoadPublishesTheRate() {
        var text: String?
        viewModel.output.rateDescription.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()

        XCTAssertEqual(text, "1 JPY = 0.2 TWD・6/13 08:00 更新")
    }

    /// 失敗時不跳提示框，匯率那一行變成可點的重試。
    func testRateFailureTurnsTheRateLineIntoARetry() {
        service.result = .failure(StubError.failure)
        var rateText: String?
        var isRetryable: Bool?
        viewModel.output.rateDescription.sink { rateText = $0 }.store(in: &cancellables)
        viewModel.output.isRateRetryable.sink { isRetryable = $0 }.store(in: &cancellables)

        XCTAssertEqual(rateText, "匯率下載中…")
        viewModel.input.viewDidLoad()
        waitForMainQueue()

        XCTAssertEqual(rateText, "匯率更新失敗・點此重試")
        XCTAssertEqual(isRetryable, true)
    }

    func testRateFailureExplainsWhyThereIsNoResult() {
        service.result = .failure(StubError.failure)
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        XCTAssertEqual(text, "輸入價格即可換算", "還沒輸入價格時，先請使用者輸入")

        viewModel.input.amountTextChanged("1000")
        XCTAssertEqual(text, "匯率無法取得，暫時無法換算")
    }

    func testRetryLoadsTheRateAndComputesTheTypedPrice() {
        service.result = .failure(StubError.failure)
        var rateText: String?
        var isRetryable: Bool?
        var text: String?
        viewModel.output.rateDescription.sink { rateText = $0 }.store(in: &cancellables)
        viewModel.output.isRateRetryable.sink { isRetryable = $0 }.store(in: &cancellables)
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")

        service.result = ExchangeRateServiceStub(yenRate: 0.2).result
        viewModel.input.retryRateTapped()
        XCTAssertEqual(rateText, "匯率下載中…")
        XCTAssertEqual(isRetryable, false, "下載中不能重複點")
        waitForMainQueue()

        XCTAssertEqual(rateText, "1 JPY = 0.2 TWD・6/13 08:00 更新")
        XCTAssertEqual(text, "未稅 NT$ 182｜NT$ 200", "重試成功後直接算出已輸入的價格")
    }

    func testRetryIsIgnoredWhenTheRateHasNotFailed() {
        var rateText: String?
        viewModel.output.rateDescription.sink { rateText = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.retryRateTapped()

        XCTAssertEqual(rateText, "1 JPY = 0.2 TWD・6/13 08:00 更新")
    }

    // MARK: - 換算

    func testComputingFromAnUntaxedPrice() {
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.taxModeChanged(to: .excludingTax)
        viewModel.input.amountTextChanged("1000")

        // 1000 * 0.2 = 200，含稅 200 * 1.1 = 220
        XCTAssertEqual(text, "未稅 NT$ 200｜NT$ 220")
    }

    func testComputingFromATaxedPrice() {
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.taxModeChanged(to: .includingTax)
        viewModel.input.amountTextChanged("1100")

        // 1100 * 0.2 = 220（含稅），未稅 220 / 1.1 = 200
        XCTAssertEqual(text, "未稅 NT$ 200｜NT$ 220")
    }

    func testNonNumericInputLeavesThePlaceholder() {
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("一千")

        XCTAssertEqual(text, "輸入價格即可換算")
    }

    /// 匯率還沒下載回來時，遷移前會用匯率 0 算出 0 元。現在先顯示提示，匯率到了再自動算出結果。
    func testInputBeforeTheRateArrivesIsComputedOnceTheRateArrives() {
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.amountTextChanged("1000")
        XCTAssertEqual(text, "匯率下載中，稍後自動換算", "有價格但還沒有匯率，說明缺的是匯率")

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        XCTAssertEqual(text, "未稅 NT$ 182｜NT$ 200")
    }

    func testChangingTaxModeRecomputes() {
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1100")
        XCTAssertEqual(text, "未稅 NT$ 200｜NT$ 220", "預設是含稅標價")

        viewModel.input.taxModeChanged(to: .excludingTax)
        XCTAssertEqual(text, "未稅 NT$ 220｜NT$ 242")
    }

    func testClearingTheAmountClearsTheResult() {
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")
        viewModel.input.amountTextChanged("")

        XCTAssertEqual(text, "輸入價格即可換算")
    }

    // MARK: - 帶價格前往下一頁

    func testUsingTheUntaxedPriceRoutesToDetail() {
        var routes: [ComputeRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")
        viewModel.input.usePrice(for: .excludingTax)

        XCTAssertEqual(routes.count, 1)
        guard case .detail(let item) = routes.first else { return XCTFail("應導向明細頁") }
        XCTAssertEqual(item.price, 182)
        XCTAssertEqual(item.taxState, "未稅")
    }

    func testUsingTheTaxedPriceRoutesToDetail() {
        var routes: [ComputeRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")
        viewModel.input.usePrice(for: .includingTax)

        guard case .detail(let item) = routes.first else { return XCTFail("應導向明細頁") }
        XCTAssertEqual(item.price, 200)
        XCTAssertEqual(item.taxState, "含稅")
    }

    /// 尚未換算就按「使用價格」，遷移前會帶著 0 元進入下一頁。
    func testUsingAPriceBeforeComputingDoesNothing() {
        var routes: [ComputeRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.usePrice(for: .excludingTax)

        XCTAssertTrue(routes.isEmpty)
    }

    /// 商品加入購物清單後，輸入框與換算結果都要清空，才能直接輸入下一件。
    func testSavingAnItemClearsTheAmountAndResult() {
        var text: String?
        var fieldTexts: [String] = []
        var routes: [ComputeRoute] = []
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)
        viewModel.output.amountFieldText.sink { fieldTexts.append($0) }.store(in: &cancellables)
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")
        viewModel.input.itemSaved()

        XCTAssertEqual(text, "輸入價格即可換算")
        XCTAssertEqual(fieldTexts.last, "")

        // 舊的價格不能再被帶到下一件商品。
        viewModel.input.usePrice(for: .excludingTax)
        XCTAssertTrue(routes.isEmpty)
        XCTAssertEqual(text, "輸入價格即可換算")
    }

    // MARK: - 商品稅率類別

    func testTaxCategorySegmentsCarryTheActualRates() {
        var titles: [String] = []
        viewModel.output.taxCategoryTitles.sink { titles = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()

        XCTAssertEqual(titles, ["一般 10%", "食品 8%"])
    }

    func testTaxCategoryIsHiddenForCurrenciesWithASingleRate() {
        var isVisible: Bool?
        viewModel.output.isTaxCategoryVisible.sink { isVisible = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        XCTAssertEqual(isVisible, true, "日幣有輕減稅率，應顯示")

        switchToWonTrip()
        viewModel.input.reloadSettings()
        XCTAssertEqual(isVisible, false, "韓幣單一稅率，應隱藏")
    }

    func testFoodCategoryUsesTheReducedRate() {
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.taxCategoryChanged(to: .reducedFood)
        viewModel.input.amountTextChanged("1000")

        // 1000 * 0.2 = 200，含稅 200 * 1.08 = 216
        XCTAssertEqual(text, "未稅 NT$ 185｜NT$ 200")
    }

    /// 以含稅價反推未稅價時，稅率類別直接決定退稅基準。
    func testCategoryChangesTheDerivedUntaxedPrice() {
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.taxModeChanged(to: .includingTax)
        viewModel.input.amountTextChanged("1080")
        XCTAssertEqual(text, "未稅 NT$ 196｜NT$ 216", "一般 10%：216 / 1.1")

        viewModel.input.taxCategoryChanged(to: .reducedFood)
        XCTAssertEqual(text, "未稅 NT$ 200｜NT$ 216", "食品 8%：216 / 1.08")
    }

    func testChangingCategoryRecomputesWithTheNewRate() {
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")
        XCTAssertEqual(text, "未稅 NT$ 182｜NT$ 200")

        viewModel.input.taxCategoryChanged(to: .reducedFood)

        XCTAssertEqual(text, "未稅 NT$ 185｜NT$ 200")
    }

    // MARK: - 幣別

    /// 幣別來自目前使用中的專案，換算頁上沒有選擇器。
    func testCurrencyComesFromTheCurrentTrip() {
        switchToWonTrip()
        viewModel = makeViewModel()
        var rateText: String?
        var placeholder: String?
        viewModel.output.rateDescription.sink { rateText = $0 }.store(in: &cancellables)
        viewModel.output.amountFieldLabel.sink { placeholder = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()

        XCTAssertEqual(rateText, "1 KRW = 0.025 TWD・6/13 08:00 更新")
        XCTAssertEqual(placeholder, "韓幣價格")
    }

    func testReloadSettingsPicksUpTheNewTripsCurrency() {
        var rateText: String?
        var placeholder: String?
        viewModel.output.rateDescription.sink { rateText = $0 }.store(in: &cancellables)
        viewModel.output.amountFieldLabel.sink { placeholder = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        XCTAssertEqual(rateText, "1 JPY = 0.2 TWD・6/13 08:00 更新")

        switchToWonTrip()
        viewModel.input.reloadSettings()

        XCTAssertEqual(rateText, "1 KRW = 0.025 TWD・6/13 08:00 更新")
        XCTAssertEqual(placeholder, "韓幣價格")
    }

    func testReloadSettingsDoesNothingWhenTheCurrencyIsUnchanged() {
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")

        viewModel.input.reloadSettings()

        XCTAssertEqual(text, "未稅 NT$ 182｜NT$ 200", "幣別沒變就不該清掉結果")
    }

    func testSettingsAndTripListRoutes() {
        var routes: [ComputeRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.settingsTapped()
        viewModel.input.tripListTapped()

        XCTAssertEqual(routes, [.settings, .tripList])
    }

    /// 沒有任何專案時不該崩潰，退回預設幣別。
    func testFallsBackToYenWhenThereIsNoTrip() {
        tripRepository.trips = []
        tripRepository.currentTripID = nil
        viewModel = makeViewModel()
        var placeholder: String?
        viewModel.output.amountFieldLabel.sink { placeholder = $0 }.store(in: &cancellables)

        XCTAssertEqual(placeholder, "日幣價格")
    }

    func testKoreanWonUsesTenPercentTax() {
        var text: String?
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        switchToWonTrip()
        viewModel.input.reloadSettings()
        viewModel.input.amountTextChanged("10000")

        // 10000 * 0.025 = 250，含稅 250 * 1.1 = 275
        XCTAssertEqual(text, "未稅 NT$ 227｜NT$ 250")
    }

    /// 換幣別後上一次的結果已經無效，不能還留在畫面上被帶去下一頁。
    func testSwitchingCurrencyClearsThePreviousResult() {
        var text: String?
        var fieldTexts: [String] = []
        var routes: [ComputeRoute] = []
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)
        viewModel.output.amountFieldText.sink { fieldTexts.append($0) }.store(in: &cancellables)
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")
        XCTAssertEqual(text, "未稅 NT$ 182｜NT$ 200")

        switchToWonTrip()
        viewModel.input.reloadSettings()

        XCTAssertEqual(text, "輸入價格即可換算")
        XCTAssertEqual(fieldTexts.last, "", "日幣的金額不能被當成韓幣重算")
        viewModel.input.usePrice(for: .excludingTax)
        XCTAssertTrue(routes.isEmpty, "結果已清空，不該還能帶價格前往下一頁")
    }

    func testShowShoppingListRoutes() {
        var routes: [ComputeRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.showShoppingListTapped()

        XCTAssertEqual(routes, [.shoppingList])
    }

    // MARK: - 首頁資訊層級

    func testTripTitleShowsFlagAndTripName() {
        var title: String?
        viewModel.output.tripTitle.sink { title = $0 }.store(in: &cancellables)

        XCTAssertEqual(title, "🇯🇵 日本")
    }

    /// 換到另一個同幣別的旅程時，幣別沒變，但標籤一定要跟著換。
    func testTripTitleUpdatesEvenWhenTheCurrencyIsUnchanged() {
        let otherYenTrip = Trip(name: "大阪", currency: .japaneseYen)
        var title: String?
        viewModel.output.tripTitle.sink { title = $0 }.store(in: &cancellables)

        tripRepository.trips = [yenTrip, otherYenTrip]
        tripRepository.currentTripID = otherYenTrip.id
        viewModel.input.reloadSettings()

        XCTAssertEqual(title, "🇯🇵 大阪")
    }

    func testCurrencySymbolFollowsTheTrip() {
        var symbol: String?
        viewModel.output.currencySymbol.sink { symbol = $0 }.store(in: &cancellables)
        XCTAssertEqual(symbol, "¥")

        switchToWonTrip()
        viewModel.input.reloadSettings()
        XCTAssertEqual(symbol, "₩")
    }

    func testAmountFieldGetsThousandsSeparators() {
        var fieldTexts: [String] = []
        var text: String?
        viewModel.output.amountFieldText.sink { fieldTexts.append($0) }.store(in: &cancellables)
        viewModel.output.result.sink { text = $0.summary }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")
        // 畫面送回來的是加過逗號的文字，計算時要能讀懂。
        viewModel.input.amountTextChanged("1,0005")

        XCTAssertEqual(fieldTexts, ["1,000", "10,005"])
        XCTAssertEqual(text, "未稅 NT$ 1,819｜NT$ 2,001")
    }

    func testResultOffersRegularAndTaxFreePurchaseWithAmounts() {
        var result: ComputeResultDisplay?
        viewModel.output.result.sink { result = $0 }.store(in: &cancellables)
        XCTAssertEqual(result, .placeholder("輸入價格即可換算"))
        XCTAssertEqual(result?.isActionable, false, "沒有結果時不顯示按鈕")

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")

        XCTAssertEqual(result?.regularPurchaseTitle, "一般購買　NT$ 200")
        XCTAssertEqual(result?.taxFreePurchaseTitle, "免稅購買　NT$ 182")
        XCTAssertEqual(result?.isActionable, true)
    }

    // MARK: - 標價未含稅開關

    /// 日韓標價大多含稅，預設未稅會讓沒注意到的人多算 10%。
    func testDefaultsToTaxInclusivePriceTags() {
        var label: String?
        var isTaxExcluded: Bool?
        viewModel.output.priceTagLabel.sink { label = $0 }.store(in: &cancellables)
        viewModel.output.isTaxExcluded.sink { isTaxExcluded = $0 }.store(in: &cancellables)

        XCTAssertEqual(label, "含稅價")
        XCTAssertEqual(isTaxExcluded, false)

        viewModel.input.taxModeChanged(to: .excludingTax)
        XCTAssertEqual(label, "未稅價")
        XCTAssertEqual(isTaxExcluded, true)
    }

    /// 未稅標價通常只是某一件商品，存完不回到含稅的話，忘了關就會一路少算稅。
    func testSavingAnItemResetsToTaxInclusive() {
        var isTaxExcluded: Bool?
        viewModel.output.isTaxExcluded.sink { isTaxExcluded = $0 }.store(in: &cancellables)

        viewModel.input.taxModeChanged(to: .excludingTax)
        viewModel.input.itemSaved()

        XCTAssertEqual(isTaxExcluded, false)
    }

    func testSwitchingCurrencyResetsToTaxInclusive() {
        var isTaxExcluded: Bool?
        viewModel.output.isTaxExcluded.sink { isTaxExcluded = $0 }.store(in: &cancellables)

        viewModel.input.taxModeChanged(to: .excludingTax)
        switchToWonTrip()
        viewModel.input.reloadSettings()

        XCTAssertEqual(isTaxExcluded, false)
    }

    /// 韓國標價一律含稅，不需要開關。
    func testToggleIsHiddenForCurrenciesWithoutTaxExcludedPriceTags() {
        var isVisible: Bool?
        viewModel.output.isTaxExcludedToggleVisible.sink { isVisible = $0 }.store(in: &cancellables)
        XCTAssertEqual(isVisible, true, "日本常見未稅標價")

        switchToWonTrip()
        viewModel.input.reloadSettings()
        XCTAssertEqual(isVisible, false)
    }

    // MARK: - VoiceOver

    /// 「NT$」會被逐字念出，朗讀版本改成「台幣 … 元」。
    func testResultHasSpokenVersionsForVoiceOver() {
        var result: ComputeResultDisplay?
        viewModel.output.result.sink { result = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("10000")

        XCTAssertEqual(result?.spokenPrimaryAmount, "含稅 台幣 2,000 元")
        XCTAssertEqual(result?.spokenSecondaryDescription, "未稅 台幣 1,818 元")
        XCTAssertEqual(result?.spokenRegularPurchase, "一般購買，台幣 2,000 元")
        XCTAssertEqual(result?.spokenTaxFreePurchase, "免稅購買，台幣 1,818 元")
    }
}
