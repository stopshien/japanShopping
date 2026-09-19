//
//  ComputeViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

/// 換算結果區要顯示的所有文字，由 ViewModel 組好，畫面只負責放上去。
struct ComputeResultDisplay: Equatable {
    /// 大字金額，為含稅價，也就是一般購買實際要付的錢。
    let primaryAmount: String
    /// 大字下方的補充，例如「未稅 NT$ 231」。沒有結果時為空字串。
    let secondaryDescription: String
    let regularPurchaseTitle: String
    let taxFreePurchaseTitle: String
    /// 有換算結果才能帶著價格前往下一頁。
    let isActionable: Bool

    static let empty = ComputeResultDisplay(
        primaryAmount: "—",
        secondaryDescription: "",
        regularPurchaseTitle: "一般購買",
        taxFreePurchaseTitle: "免稅購買",
        isActionable: false
    )

    init(primaryAmount: String, secondaryDescription: String,
         regularPurchaseTitle: String, taxFreePurchaseTitle: String, isActionable: Bool) {
        self.primaryAmount = primaryAmount
        self.secondaryDescription = secondaryDescription
        self.regularPurchaseTitle = regularPurchaseTitle
        self.taxFreePurchaseTitle = taxFreePurchaseTitle
        self.isActionable = isActionable
    }

    init(breakdown: PriceBreakdown) {
        let taxed = PriceText.twd(breakdown.taxed)
        let untaxed = PriceText.twd(breakdown.untaxed)
        self.init(
            primaryAmount: taxed,
            secondaryDescription: "未稅 \(untaxed)",
            regularPurchaseTitle: "一般購買　\(taxed)",
            taxFreePurchaseTitle: "免稅購買　\(untaxed)",
            isActionable: true
        )
    }
}

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
    /// 從旅程清單返回後重新讀取目前的旅程與幣別。
    func reloadSettings()
    func taxCategoryChanged(to category: TaxCategory)
    func amountTextChanged(_ text: String)
    /// 標價是否未含稅。預設為含稅，由「標價未含稅（税抜）」開關切換。
    func taxModeChanged(to mode: TaxMode)
    /// 一般購買付含稅價、免稅購買付未稅價。存進紀錄的仍是「含稅」或「未稅」。
    func usePrice(for mode: TaxMode)
    /// 商品已加入購物清單，清掉輸入的價格與換算結果，準備輸入下一件。
    func itemSaved()
    func showShoppingListTapped()
    func settingsTapped()
    func tripListTapped()
}

protocol ComputeViewModelOutput {
    /// 導覽列中間的旅程標籤，例如「🇰🇷 首爾」。
    var tripTitle: AnyPublisher<String, Never> { get }
    /// 匯率與更新時間，例如「1 KRW = 0.0231 TWD・9/18 16:00 更新」。
    var rateDescription: AnyPublisher<String, Never> { get }
    var currencySymbol: AnyPublisher<String, Never> { get }
    /// 金額輸入框給 VoiceOver 的名稱，例如「韓幣價格」。
    var amountFieldLabel: AnyPublisher<String, Never> { get }
    var taxCategoryTitles: AnyPublisher<[String], Never> { get }
    var isTaxCategoryVisible: AnyPublisher<Bool, Never> { get }
    /// 輸入框旁的標註，「含稅價」或「未稅價」。
    var priceTagLabel: AnyPublisher<String, Never> { get }
    /// 目前是否以未稅標價換算，決定開關狀態與標註的強調色。
    var isTaxExcluded: AnyPublisher<Bool, Never> { get }
    /// 只有常見未稅標價的國家才顯示開關。
    var isTaxExcludedToggleVisible: AnyPublisher<Bool, Never> { get }
    var result: AnyPublisher<ComputeResultDisplay, Never> { get }
    /// 需要改寫輸入框內容時送出：加上千分位，或清空。
    var amountFieldText: AnyPublisher<String, Never> { get }
    var route: AnyPublisher<ComputeRoute, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
}

// MARK: - ViewModel

final class ComputeViewModel: ComputeViewModelType {

    private enum Constants {
        static let rateSignificantDigits = 4
    }

    private let service: ExchangeRateService
    private let tripRepository: TripRepository
    private let updatedAtFormatter: DateFormatter
    private let rateFormatter: NumberFormatter

    private var exchangeRate: ExchangeRate?
    private var currency: Currency
    private var updatedAt: String?
    private var amountText = ""
    /// 預設含稅：日韓的標價大多含稅，預設未稅會讓沒注意到的人多算 10%。
    private var taxMode: TaxMode = .includingTax
    private var taxCategory: TaxCategory = .standard
    private var breakdown: PriceBreakdown?
    private var cancellables = Set<AnyCancellable>()

    private let tripTitleSubject: CurrentValueSubject<String, Never>
    private let rateDescriptionSubject = CurrentValueSubject<String, Never>("")
    private let currencySymbolSubject: CurrentValueSubject<String, Never>
    private let amountFieldLabelSubject: CurrentValueSubject<String, Never>
    private let taxCategoryTitlesSubject: CurrentValueSubject<[String], Never>
    private let isTaxCategoryVisibleSubject: CurrentValueSubject<Bool, Never>
    private let priceTagLabelSubject = CurrentValueSubject<String, Never>(TaxMode.includingTax.priceTagLabel)
    private let isTaxExcludedSubject = CurrentValueSubject<Bool, Never>(false)
    private let isTaxExcludedToggleVisibleSubject: CurrentValueSubject<Bool, Never>
    private let resultSubject = CurrentValueSubject<ComputeResultDisplay, Never>(.empty)
    private let amountFieldTextSubject = PassthroughSubject<String, Never>()
    private let routeSubject = PassthroughSubject<ComputeRoute, Never>()
    private let errorMessageSubject = PassthroughSubject<String, Never>()

    init(service: ExchangeRateService, tripRepository: TripRepository) {
        self.service = service
        self.tripRepository = tripRepository
        self.updatedAtFormatter = ComputeViewModel.makeUpdatedAtFormatter()
        self.rateFormatter = ComputeViewModel.makeRateFormatter()
        let initialTrip = ComputeViewModel.currentTrip(from: tripRepository)
        let initialCurrency = initialTrip?.currency ?? .japaneseYen
        self.currency = initialCurrency
        self.tripTitleSubject = CurrentValueSubject(ComputeViewModel.tripTitle(for: initialTrip, currency: initialCurrency))
        self.currencySymbolSubject = CurrentValueSubject(initialCurrency.symbol)
        self.amountFieldLabelSubject = CurrentValueSubject(initialCurrency.amountLabel)
        self.taxCategoryTitlesSubject = CurrentValueSubject(ComputeViewModel.taxCategoryTitles(for: initialCurrency))
        self.isTaxCategoryVisibleSubject = CurrentValueSubject(initialCurrency.hasReducedTaxRate)
        self.isTaxExcludedToggleVisibleSubject = CurrentValueSubject(initialCurrency.hasTaxExcludedPriceTags)
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

    /// 匯率只需要看出大小，取 4 位有效數字（0.2045、0.02308），不會出現 0.20449999 這種尾數。
    private static func makeRateFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = Constants.rateSignificantDigits
        return formatter
    }

    /// 以台北時間顯示，例如「6/13 08:00」。
    private func describeUpdatedAt(_ rawValue: String) -> String? {
        guard let date = updatedAtFormatter.date(from: rawValue) else { return nil }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "en_US_POSIX")
        displayFormatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        displayFormatter.dateFormat = "M/d HH:mm"
        return displayFormatter.string(from: date)
    }

    /// 幣別或匯率變動後，重新顯示匯率並以新的匯率重算。
    private func refreshForCurrentCurrency() {
        currencySymbolSubject.send(currency.symbol)
        amountFieldLabelSubject.send(currency.amountLabel)
        taxCategoryTitlesSubject.send(Self.taxCategoryTitles(for: currency))
        isTaxCategoryVisibleSubject.send(currency.hasReducedTaxRate)
        isTaxExcludedToggleVisibleSubject.send(currency.hasTaxExcludedPriceTags)
        publishRateDescription()
        recompute()
    }

    private func publishRateDescription() {
        guard let exchangeRate else { return }
        let rate = exchangeRate.rateToTaiwanDollar(for: currency)
        let rateText = rateFormatter.string(from: NSNumber(value: rate)) ?? "\(rate)"
        var description = "1 \(currency.code) = \(rateText) TWD"
        if let updatedAt {
            description += "・\(updatedAt) 更新"
        }
        rateDescriptionSubject.send(description)
    }

    /// 目前使用中的旅程。沒有選中時退回最新建立的一個。
    private static func currentTrip(from repository: TripRepository) -> Trip? {
        let trips = (try? repository.load()) ?? []
        if let id = repository.loadCurrentTripID(), let trip = trips.first(where: { $0.id == id }) {
            return trip
        }
        return trips.sorted { $0.createdAt > $1.createdAt }.first
    }

    private static func tripTitle(for trip: Trip?, currency: Currency) -> String {
        "\(currency.flag) \(trip?.name ?? currency.title)"
    }

    /// 標籤帶上實際稅率（例如「食品 8%」），稅率調整時標籤不會對不上。
    private static func taxCategoryTitles(for currency: Currency) -> [String] {
        TaxCategory.allCases.map { "\($0.title) \(currency.taxPercent(for: $0))%" }
    }

    private func setTaxMode(_ mode: TaxMode) {
        taxMode = mode
        priceTagLabelSubject.send(mode.priceTagLabel)
        isTaxExcludedSubject.send(mode == .excludingTax)
    }

    private func resetTaxMode() {
        setTaxMode(.includingTax)
    }

    private func clearAmount() {
        amountText = ""
        amountFieldTextSubject.send("")
    }

    private func clearResult() {
        breakdown = nil
        resultSubject.send(.empty)
    }

    /// 任何會影響結果的輸入變動時都重算。
    /// 匯率還沒到或金額不是數字時只顯示提示，不會產生 0 元的結果。
    private func recompute() {
        guard let exchangeRate, let amount = Double(amountText) else {
            clearResult()
            return
        }

        let breakdown = PriceBreakdown(
            amount: amount,
            rate: exchangeRate.rateToTaiwanDollar(for: currency),
            mode: taxMode,
            taxMultiplier: currency.taxMultiplier(for: taxCategory)
        )
        self.breakdown = breakdown
        resultSubject.send(ComputeResultDisplay(breakdown: breakdown))
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
                    self.updatedAt = self.describeUpdatedAt(exchangeRate.lastUpdatedUTC)
                    self.refreshForCurrentCurrency()
                }
            )
            .store(in: &cancellables)
    }

    func reloadSettings() {
        let updatedTrip = Self.currentTrip(from: tripRepository)
        let updated = updatedTrip?.currency ?? .japaneseYen
        // 旅程改名或換到同幣別的另一個旅程，標籤也要跟著變。
        tripTitleSubject.send(Self.tripTitle(for: updatedTrip, currency: updated))
        guard updated != currency else { return }
        currency = updated
        // 輸入的數字是舊幣別的價格，不能直接當成新幣別重算。
        clearAmount()
        resetTaxMode()
        refreshForCurrentCurrency()
    }

    func taxCategoryChanged(to category: TaxCategory) {
        guard category != taxCategory else { return }
        taxCategory = category
        recompute()
    }

    /// 輸入框顯示的是加上千分位的文字，計算前先去掉逗號。
    func amountTextChanged(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        amountText = trimmed.replacingOccurrences(of: ",", with: "")
        if let grouped = PriceText.groupedInput(amountText), grouped != trimmed {
            amountFieldTextSubject.send(grouped)
        }
        recompute()
    }

    func taxModeChanged(to mode: TaxMode) {
        setTaxMode(mode)
        recompute()
    }

    /// 尚未換算出結果前不會前往下一頁，避免帶著 0 元的價格建立項目。
    func usePrice(for mode: TaxMode) {
        guard let item = makeItem(for: mode) else { return }
        routeSubject.send(.detail(item))
    }

    /// 未稅標價通常只是某一件商品的情況，存完就回到含稅，
    /// 否則忘了關開關，之後每一筆都會少算稅。
    func itemSaved() {
        clearAmount()
        resetTaxMode()
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

    var tripTitle: AnyPublisher<String, Never> { tripTitleSubject.eraseToAnyPublisher() }
    var rateDescription: AnyPublisher<String, Never> { rateDescriptionSubject.eraseToAnyPublisher() }
    var currencySymbol: AnyPublisher<String, Never> { currencySymbolSubject.eraseToAnyPublisher() }
    var amountFieldLabel: AnyPublisher<String, Never> { amountFieldLabelSubject.eraseToAnyPublisher() }
    var taxCategoryTitles: AnyPublisher<[String], Never> { taxCategoryTitlesSubject.eraseToAnyPublisher() }
    var isTaxCategoryVisible: AnyPublisher<Bool, Never> { isTaxCategoryVisibleSubject.eraseToAnyPublisher() }
    var priceTagLabel: AnyPublisher<String, Never> { priceTagLabelSubject.eraseToAnyPublisher() }
    var isTaxExcluded: AnyPublisher<Bool, Never> { isTaxExcludedSubject.eraseToAnyPublisher() }
    var isTaxExcludedToggleVisible: AnyPublisher<Bool, Never> {
        isTaxExcludedToggleVisibleSubject.eraseToAnyPublisher()
    }
    var result: AnyPublisher<ComputeResultDisplay, Never> { resultSubject.eraseToAnyPublisher() }
    var amountFieldText: AnyPublisher<String, Never> { amountFieldTextSubject.eraseToAnyPublisher() }
    var route: AnyPublisher<ComputeRoute, Never> { routeSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
}
