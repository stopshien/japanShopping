//
//  ComputeViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

enum ComputeRoute: Equatable {
    case detail(ShoppingItem)
    case shoppingList
    case settings
    case tripList
}

protocol ComputeViewModelType {
    var input: ComputeViewModelInput { get }
    var output: ComputeViewModelOutput { get }
}

protocol ComputeViewModelInput {
    func viewDidLoad()
    /// 從設定頁或專案清單返回後重新讀取幣別。
    func reloadSettings()
    func taxCategoryChanged(to category: TaxCategory)
    func amountTextChanged(_ text: String)
    func taxModeChanged(to mode: TaxMode)
    func computeTapped()
    func usePrice(for mode: TaxMode)
    /// 商品已加入購物清單，清掉輸入的價格與換算結果，準備輸入下一件。
    func itemSaved()
    func showShoppingListTapped()
    func settingsTapped()
    func tripListTapped()
}

protocol ComputeViewModelOutput {
    var rateDescription: AnyPublisher<String, Never> { get }
    var inputPlaceholder: AnyPublisher<String, Never> { get }
    var taxCategoryTitles: AnyPublisher<[String], Never> { get }
    var isTaxCategoryVisible: AnyPublisher<Bool, Never> { get }
    var updatedAtDescription: AnyPublisher<String, Never> { get }
    var resultText: AnyPublisher<String, Never> { get }
    /// 需要改寫輸入框內容時送出。
    var amountFieldText: AnyPublisher<String, Never> { get }
    var route: AnyPublisher<ComputeRoute, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
}

// MARK: - ViewModel

final class ComputeViewModel: ComputeViewModelType {

    private enum Constants {
        static let resultPlaceholder = "換算結果"
        static let rateUnavailable = "匯率尚未取得，請稍候再試"
    }

    private let service: ExchangeRateService
    private let tripRepository: TripRepository
    private let updatedAtFormatter: DateFormatter

    private var exchangeRate: ExchangeRate?
    private var currency: Currency
    private var amountText = ""
    private var taxMode: TaxMode = .excludingTax
    private var taxCategory: TaxCategory = .standard
    private var breakdown: PriceBreakdown?
    private var cancellables = Set<AnyCancellable>()

    private let rateDescriptionSubject = CurrentValueSubject<String, Never>("")
    private let inputPlaceholderSubject: CurrentValueSubject<String, Never>
    private let taxCategoryTitlesSubject: CurrentValueSubject<[String], Never>
    private let isTaxCategoryVisibleSubject: CurrentValueSubject<Bool, Never>
    private let updatedAtDescriptionSubject = CurrentValueSubject<String, Never>("")
    private let resultTextSubject = CurrentValueSubject<String, Never>(Constants.resultPlaceholder)
    private let amountFieldTextSubject = PassthroughSubject<String, Never>()
    private let routeSubject = PassthroughSubject<ComputeRoute, Never>()
    private let errorMessageSubject = PassthroughSubject<String, Never>()

    init(service: ExchangeRateService, tripRepository: TripRepository) {
        self.service = service
        self.tripRepository = tripRepository
        self.updatedAtFormatter = ComputeViewModel.makeUpdatedAtFormatter()
        let initialCurrency = ComputeViewModel.currentCurrency(from: tripRepository)
        self.currency = initialCurrency
        self.inputPlaceholderSubject = CurrentValueSubject(initialCurrency.inputPlaceholder)
        self.taxCategoryTitlesSubject = CurrentValueSubject(ComputeViewModel.taxCategoryTitles(for: initialCurrency))
        self.isTaxCategoryVisibleSubject = CurrentValueSubject(initialCurrency.hasReducedTaxRate)
    }

    var input: ComputeViewModelInput { self }
    var output: ComputeViewModelOutput { self }

    // MARK: - Private

    /// API 回傳的是英文的 RFC 1123 時間字串，
    /// 必須用 en_US_POSIX 解析，否則在非英文語系裝置上會解析失敗。
    private static func makeUpdatedAtFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
        return formatter
    }

    private func describeUpdatedAt(_ rawValue: String) -> String? {
        guard let date = updatedAtFormatter.date(from: rawValue) else { return nil }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        displayFormatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        displayFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss"
        return displayFormatter.string(from: date)
    }

    /// 幣別或匯率變動後，重新顯示匯率並清掉上一次的換算結果。
    private func refreshForCurrentCurrency() {
        inputPlaceholderSubject.send(currency.inputPlaceholder)
        taxCategoryTitlesSubject.send(Self.taxCategoryTitles(for: currency))
        isTaxCategoryVisibleSubject.send(currency.hasReducedTaxRate)

        if let exchangeRate {
            rateDescriptionSubject.send("\(currency.title)匯率：\(exchangeRate.rateToTaiwanDollar(for: currency))")
        }

        breakdown = nil
        resultTextSubject.send(Constants.resultPlaceholder)
    }

    /// 目前使用中專案的幣別。沒有選中時退回最新建立的一個。
    private static func currentCurrency(from repository: TripRepository) -> Currency {
        let trips = (try? repository.load()) ?? []
        if let id = repository.loadCurrentTripID(), let trip = trips.first(where: { $0.id == id }) {
            return trip.currency
        }
        return trips.sorted { $0.createdAt > $1.createdAt }.first?.currency ?? .japaneseYen
    }

    /// 標籤帶上實際稅率（例如「食品 8%」），稅率調整時標籤不會對不上。
    private static func taxCategoryTitles(for currency: Currency) -> [String] {
        TaxCategory.allCases.map { "\($0.title) \(currency.taxPercent(for: $0))%" }
    }

    /// 換算結果會隨稅率改變，因此稅率相關的選擇變動時要一併清掉。
    private func clearResult() {
        breakdown = nil
        resultTextSubject.send(Constants.resultPlaceholder)
    }

    private func makeItem(for mode: TaxMode) -> ShoppingItem? {
        guard let breakdown else { return nil }
        let price = mode == .excludingTax ? breakdown.untaxed : breakdown.taxed
        return ShoppingItem(productName: "", price: price, payType: "", taxState: mode.title)
    }
}

// MARK: - ComputeViewModelInput

extension ComputeViewModel: ComputeViewModelInput {

    func viewDidLoad() {
        service.latestRate()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard case .failure = completion else { return }
                    self?.errorMessageSubject.send("匯率下載失敗，請檢查網路後再試")
                },
                receiveValue: { [weak self] exchangeRate in
                    guard let self else { return }
                    self.exchangeRate = exchangeRate
                    self.refreshForCurrentCurrency()
                    if let updatedAt = self.describeUpdatedAt(exchangeRate.lastUpdatedUTC) {
                        self.updatedAtDescriptionSubject.send("匯率更新於：\(updatedAt)")
                    }
                }
            )
            .store(in: &cancellables)
    }

    func reloadSettings() {
        let updated = Self.currentCurrency(from: tripRepository)
        guard updated != currency else { return }
        currency = updated
        refreshForCurrentCurrency()
    }

    func taxCategoryChanged(to category: TaxCategory) {
        guard category != taxCategory else { return }
        taxCategory = category
        clearResult()
    }

    func amountTextChanged(_ text: String) {
        amountText = text.trimmingCharacters(in: .whitespaces)
    }

    func taxModeChanged(to mode: TaxMode) {
        taxMode = mode
    }

    func computeTapped() {
        guard let exchangeRate else {
            errorMessageSubject.send(Constants.rateUnavailable)
            return
        }
        guard let amount = Double(amountText) else {
            breakdown = nil
            resultTextSubject.send(Constants.resultPlaceholder)
            return
        }

        let breakdown = PriceBreakdown(
            amount: amount,
            rate: exchangeRate.rateToTaiwanDollar(for: currency),
            mode: taxMode,
            taxMultiplier: currency.taxMultiplier(for: taxCategory)
        )
        self.breakdown = breakdown
        resultTextSubject.send(
            "台幣 \n未稅：\(PriceText.amount(breakdown.untaxed))\n含稅：\(PriceText.amount(breakdown.taxed))"
        )
    }

    /// 尚未換算出結果前不會前往下一頁，避免帶著 0 元的價格建立項目。
    func usePrice(for mode: TaxMode) {
        guard let item = makeItem(for: mode) else { return }
        routeSubject.send(.detail(item))
    }

    func itemSaved() {
        amountText = ""
        amountFieldTextSubject.send("")
        clearResult()
    }

    func showShoppingListTapped() {
        routeSubject.send(.shoppingList)
    }

    func settingsTapped() {
        routeSubject.send(.settings)
    }

    func tripListTapped() {
        routeSubject.send(.tripList)
    }
}

// MARK: - ComputeViewModelOutput

extension ComputeViewModel: ComputeViewModelOutput {

    var rateDescription: AnyPublisher<String, Never> { rateDescriptionSubject.eraseToAnyPublisher() }
    var inputPlaceholder: AnyPublisher<String, Never> { inputPlaceholderSubject.eraseToAnyPublisher() }
    var taxCategoryTitles: AnyPublisher<[String], Never> { taxCategoryTitlesSubject.eraseToAnyPublisher() }
    var isTaxCategoryVisible: AnyPublisher<Bool, Never> { isTaxCategoryVisibleSubject.eraseToAnyPublisher() }
    var updatedAtDescription: AnyPublisher<String, Never> { updatedAtDescriptionSubject.eraseToAnyPublisher() }
    var resultText: AnyPublisher<String, Never> { resultTextSubject.eraseToAnyPublisher() }
    var amountFieldText: AnyPublisher<String, Never> { amountFieldTextSubject.eraseToAnyPublisher() }
    var route: AnyPublisher<ComputeRoute, Never> { routeSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
}
