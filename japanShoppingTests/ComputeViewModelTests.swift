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

final class ComputeViewModelTests: XCTestCase {

    private var service: ExchangeRateServiceStub!
    private var viewModel: ComputeViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        service = ExchangeRateServiceStub(yenRate: 0.2, wonRate: 0.025)
        viewModel = ComputeViewModel(service: service)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        service = nil
        super.tearDown()
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

        XCTAssertEqual(text, "日幣匯率：0.2")
    }

    func testViewDidLoadPublishesTheUpdateTimeInTaipeiTime() {
        var text: String?
        viewModel.output.updatedAtDescription.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()

        // UTC 00:00:01 在台北是同日 08:00:01
        XCTAssertEqual(text, "匯率更新於：Fri, 13 Jun 2025 08:00:01")
    }

    func testRateFailureReportsAnError() {
        service.result = .failure(StubError.failure)
        var message: String?
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()

        XCTAssertEqual(message, "匯率下載失敗，請檢查網路後再試")
    }

    // MARK: - 換算

    func testComputingFromAnUntaxedPrice() {
        var text: String?
        viewModel.output.resultText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.taxModeChanged(to: .excludingTax)
        viewModel.input.amountTextChanged("1000")
        viewModel.input.computeTapped()

        // 1000 * 0.2 = 200，含稅 200 * 1.1 = 220
        XCTAssertEqual(text, "台幣 \n未稅：200\n含稅：220")
    }

    func testComputingFromATaxedPrice() {
        var text: String?
        viewModel.output.resultText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.taxModeChanged(to: .includingTax)
        viewModel.input.amountTextChanged("1100")
        viewModel.input.computeTapped()

        // 1100 * 0.2 = 220（含稅），未稅 220 / 1.1 = 200
        XCTAssertEqual(text, "台幣 \n未稅：200\n含稅：220")
    }

    func testNonNumericInputLeavesThePlaceholder() {
        var text: String?
        viewModel.output.resultText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("一千")
        viewModel.input.computeTapped()

        XCTAssertEqual(text, "換算結果")
    }

    /// 匯率還沒下載回來時換算，遷移前會用匯率 0 算出 0 元。
    func testComputingBeforeTheRateArrivesReportsAnError() {
        var message: String?
        var text: String?
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)
        viewModel.output.resultText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.amountTextChanged("1000")
        viewModel.input.computeTapped()

        XCTAssertEqual(message, "匯率尚未取得，請稍候再試")
        XCTAssertEqual(text, "換算結果")
    }

    // MARK: - 帶價格前往下一頁

    func testUsingTheUntaxedPriceRoutesToDetail() {
        var routes: [ComputeRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")
        viewModel.input.computeTapped()
        viewModel.input.usePrice(for: .excludingTax)

        XCTAssertEqual(routes.count, 1)
        guard case .detail(let item) = routes.first else { return XCTFail("應導向明細頁") }
        XCTAssertEqual(item.price, 200)
        XCTAssertEqual(item.taxState, "未稅")
    }

    func testUsingTheTaxedPriceRoutesToDetail() {
        var routes: [ComputeRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")
        viewModel.input.computeTapped()
        viewModel.input.usePrice(for: .includingTax)

        guard case .detail(let item) = routes.first else { return XCTFail("應導向明細頁") }
        XCTAssertEqual(item.price, 220)
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

    // MARK: - 幣別

    func testSwitchingCurrencyUpdatesTheRateAndPlaceholder() {
        var rateText: String?
        var placeholder: String?
        viewModel.output.rateDescription.sink { rateText = $0 }.store(in: &cancellables)
        viewModel.output.inputPlaceholder.sink { placeholder = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        XCTAssertEqual(rateText, "日幣匯率：0.2")
        XCTAssertEqual(placeholder, "請輸入日幣價格...")

        viewModel.input.currencyChanged(to: .koreanWon)

        XCTAssertEqual(rateText, "韓幣匯率：0.025")
        XCTAssertEqual(placeholder, "請輸入韓幣價格...")
    }

    func testKoreanWonUsesTenPercentTax() {
        var text: String?
        viewModel.output.resultText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.currencyChanged(to: .koreanWon)
        viewModel.input.amountTextChanged("10000")
        viewModel.input.computeTapped()

        // 10000 * 0.025 = 250，含稅 250 * 1.1 = 275
        XCTAssertEqual(text, "台幣 \n未稅：250\n含稅：275")
    }

    /// 換幣別後上一次的結果已經無效，不能還留在畫面上被帶去下一頁。
    func testSwitchingCurrencyClearsThePreviousResult() {
        var text: String?
        var routes: [ComputeRoute] = []
        viewModel.output.resultText.sink { text = $0 }.store(in: &cancellables)
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")
        viewModel.input.computeTapped()
        XCTAssertEqual(text, "台幣 \n未稅：200\n含稅：220")

        viewModel.input.currencyChanged(to: .koreanWon)

        XCTAssertEqual(text, "換算結果")
        viewModel.input.usePrice(for: .excludingTax)
        XCTAssertTrue(routes.isEmpty, "結果已清空，不該還能帶價格前往下一頁")
    }

    func testSelectingTheSameCurrencyDoesNotClearTheResult() {
        var text: String?
        viewModel.output.resultText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.amountTextChanged("1000")
        viewModel.input.computeTapped()

        viewModel.input.currencyChanged(to: .japaneseYen)

        XCTAssertEqual(text, "台幣 \n未稅：200\n含稅：220")
    }

    func testShowShoppingListRoutes() {
        var routes: [ComputeRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.showShoppingListTapped()

        XCTAssertEqual(routes, [.shoppingList])
    }
}
