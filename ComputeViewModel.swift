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
}

protocol ComputeViewModelType {
    var input: ComputeViewModelInput { get }
    var output: ComputeViewModelOutput { get }
}

protocol ComputeViewModelInput {
    func viewDidLoad()
    func currencyChanged(to currency: Currency)
    func amountTextChanged(_ text: String)
    func taxModeChanged(to mode: TaxMode)
    func computeTapped()
    func usePrice(for mode: TaxMode)
    func showShoppingListTapped()
}

protocol ComputeViewModelOutput {
    var rateDescription: AnyPublisher<String, Never> { get }
    var inputPlaceholder: AnyPublisher<String, Never> { get }
    var updatedAtDescription: AnyPublisher<String, Never> { get }
    var resultText: AnyPublisher<String, Never> { get }
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
    private let updatedAtFormatter: DateFormatter

    private var exchangeRate: ExchangeRate?
    private var currency: Currency = .japaneseYen
    private var amountText = ""
    private var taxMode: TaxMode = .excludingTax
    private var breakdown: PriceBreakdown?
    private var cancellables = Set<AnyCancellable>()

    private let rateDescriptionSubject = CurrentValueSubject<String, Never>("")
    private let inputPlaceholderSubject: CurrentValueSubject<String, Never>
    private let updatedAtDescriptionSubject = CurrentValueSubject<String, Never>("")
    private let resultTextSubject = CurrentValueSubject<String, Never>(Constants.resultPlaceholder)
    private let routeSubject = PassthroughSubject<ComputeRoute, Never>()
    private let errorMessageSubject = PassthroughSubject<String, Never>()

    init(service: ExchangeRateService) {
        self.service = service
        self.updatedAtFormatter = ComputeViewModel.makeUpdatedAtFormatter()
        self.inputPlaceholderSubject = CurrentValueSubject(Currency.japaneseYen.inputPlaceholder)
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

        if let exchangeRate {
            rateDescriptionSubject.send("\(currency.title)匯率：\(exchangeRate.rateToTaiwanDollar(for: currency))")
        }

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

    func currencyChanged(to currency: Currency) {
        guard currency != self.currency else { return }
        self.currency = currency
        refreshForCurrentCurrency()
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
            taxMultiplier: currency.taxMultiplier
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

    func showShoppingListTapped() {
        routeSubject.send(.shoppingList)
    }
}

// MARK: - ComputeViewModelOutput

extension ComputeViewModel: ComputeViewModelOutput {

    var rateDescription: AnyPublisher<String, Never> { rateDescriptionSubject.eraseToAnyPublisher() }
    var inputPlaceholder: AnyPublisher<String, Never> { inputPlaceholderSubject.eraseToAnyPublisher() }
    var updatedAtDescription: AnyPublisher<String, Never> { updatedAtDescriptionSubject.eraseToAnyPublisher() }
    var resultText: AnyPublisher<String, Never> { resultTextSubject.eraseToAnyPublisher() }
    var route: AnyPublisher<ComputeRoute, Never> { routeSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
}
