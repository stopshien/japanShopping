//
//  ComputeViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

private final class ExchangeRateServiceStub: ExchangeRateService {

    var result: Result<ExchangeRate, Error>

    init(rate: Double = 0.2) {
        // TWD / JPY 即為日圓兌台幣匯率。
        self.result = .success(
            ExchangeRate(
                lastUpdatedUTC: "Fri, 13 Jun 2025 00:00:01 +0000",
                conversionRates: ConversionRates(usd: 1, jpy: 1, twd: rate)
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
        service = ExchangeRateServiceStub(rate: 0.2)
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

        XCTAssertEqual(text, "匯率：0.2")
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
        viewModel.input.yenTextChanged("1000")
        viewModel.input.computeTapped()

        // 1000 * 0.2 = 200，含稅 200 * 1.08 = 216
        XCTAssertEqual(text, "台幣 \n未稅：200\n含稅：216")
    }

    func testComputingFromATaxedPrice() {
        var text: String?
        viewModel.output.resultText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.taxModeChanged(to: .includingTax)
        viewModel.input.yenTextChanged("1080")
        viewModel.input.computeTapped()

        // 1080 * 0.2 = 216（含稅），未稅 216 / 1.08 = 200
        XCTAssertEqual(text, "台幣 \n未稅：200\n含稅：216")
    }

    func testNonNumericInputLeavesThePlaceholder() {
        var text: String?
        viewModel.output.resultText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        waitForMainQueue()
        viewModel.input.yenTextChanged("一千")
        viewModel.input.computeTapped()

        XCTAssertEqual(text, "換算結果")
    }

    /// 匯率還沒下載回來時換算，遷移前會用匯率 0 算出 0 元。
    func testComputingBeforeTheRateArrivesReportsAnError() {
        var message: String?
        var text: String?
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)
        viewModel.output.resultText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.yenTextChanged("1000")
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
        viewModel.input.yenTextChanged("1000")
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
        viewModel.input.yenTextChanged("1000")
        viewModel.input.computeTapped()
        viewModel.input.usePrice(for: .includingTax)

        guard case .detail(let item) = routes.first else { return XCTFail("應導向明細頁") }
        XCTAssertEqual(item.price, 216)
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

    func testShowShoppingListRoutes() {
        var routes: [ComputeRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.showShoppingListTapped()

        XCTAssertEqual(routes, [.shoppingList])
    }
}

// MARK: - PriceBreakdown

final class PriceBreakdownTests: XCTestCase {

    func testUntaxedModeDerivesTheTaxedPrice() {
        let breakdown = PriceBreakdown(yen: 1000, rate: 0.2, mode: .excludingTax)

        XCTAssertEqual(breakdown.untaxed, 200)
        XCTAssertEqual(breakdown.taxed, 216)
    }

    func testTaxedModeDerivesTheUntaxedPrice() {
        let breakdown = PriceBreakdown(yen: 1080, rate: 0.2, mode: .includingTax)

        XCTAssertEqual(breakdown.taxed, 216)
        XCTAssertEqual(breakdown.untaxed, 200)
    }

    func testBothPricesAreRoundedToWholeDollars() {
        let breakdown = PriceBreakdown(yen: 999, rate: 0.2055, mode: .excludingTax)

        XCTAssertEqual(breakdown.untaxed, breakdown.untaxed.rounded())
        XCTAssertEqual(breakdown.taxed, breakdown.taxed.rounded())
    }
}
