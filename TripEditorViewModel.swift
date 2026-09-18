//
//  TripEditorViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

protocol TripEditorViewModelType {
    var input: TripEditorViewModelInput { get }
    var output: TripEditorViewModelOutput { get }
}

protocol TripEditorViewModelInput {
    func viewDidLoad()
    func nameChanged(_ text: String)
    func currencySelected(_ currency: Currency)
    func confirmTapped()
}

protocol TripEditorViewModelOutput {
    var name: AnyPublisher<String, Never> { get }
    var selectedCurrency: AnyPublisher<Currency, Never> { get }
    var taxDescription: AnyPublisher<String, Never> { get }
    var isConfirmEnabled: AnyPublisher<Bool, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didFinish: AnyPublisher<Void, Never> { get }
}

// MARK: - ViewModel

/// 建立或修改一個專案。引導流程的第二步與專案清單的「新增」共用同一個畫面。
final class TripEditorViewModel: TripEditorViewModelType {

    /// 編輯既有專案時帶入該專案，建立新專案時為 nil。
    private let editingTrip: Trip?
    private let repository: TripRepository

    private var currentName = ""
    private var currency: Currency = .japaneseYen
    /// 使用者是否自己改過名稱。沒改過的話切換幣別會一併更新預設名稱。
    private var hasCustomName = false

    private let nameSubject = CurrentValueSubject<String, Never>("")
    private let selectedCurrencySubject = CurrentValueSubject<Currency, Never>(.japaneseYen)
    private let taxDescriptionSubject = CurrentValueSubject<String, Never>("")
    private let isConfirmEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didFinishSubject = PassthroughSubject<Void, Never>()

    init(editingTrip: Trip? = nil, repository: TripRepository) {
        self.editingTrip = editingTrip
        self.repository = repository
    }

    var input: TripEditorViewModelInput { self }
    var output: TripEditorViewModelOutput { self }

    // MARK: - Private

    /// 說明該幣別會套用的稅率，讓使用者知道選擇的後果。
    private static func describeTax(_ currency: Currency) -> String {
        guard currency.hasReducedTaxRate else {
            return "稅率：\(currency.taxPercent(for: .standard))%"
        }
        let rates = TaxCategory.allCases
            .map { "\($0.title) \(currency.taxPercent(for: $0))%" }
            .joined(separator: "、")
        return "稅率：\(rates)，可於每筆消費切換"
    }

    private func publishName(_ value: String) {
        currentName = value
        nameSubject.send(value)
        isConfirmEnabledSubject.send(!value.isEmpty)
    }
}

// MARK: - TripEditorViewModelInput

extension TripEditorViewModel: TripEditorViewModelInput {

    func viewDidLoad() {
        if let editingTrip {
            currency = editingTrip.currency
            hasCustomName = true
            publishName(editingTrip.name)
        } else {
            publishName(Trip.defaultName(for: currency))
        }
        selectedCurrencySubject.send(currency)
        taxDescriptionSubject.send(Self.describeTax(currency))
    }

    func nameChanged(_ text: String) {
        hasCustomName = true
        publishName(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func currencySelected(_ currency: Currency) {
        guard currency != self.currency else { return }
        self.currency = currency
        selectedCurrencySubject.send(currency)
        taxDescriptionSubject.send(Self.describeTax(currency))

        // 使用者沒自己命名過，預設名稱才跟著幣別走。
        if !hasCustomName {
            publishName(Trip.defaultName(for: currency))
        }
    }

    func confirmTapped() {
        guard !currentName.isEmpty else { return }

        do {
            var trips = try repository.load()
            if let editingTrip, let index = trips.firstIndex(where: { $0.id == editingTrip.id }) {
                trips[index].name = currentName
                trips[index].currency = currency
                try repository.save(trips)
            } else {
                let trip = Trip(name: currentName, currency: currency)
                trips.append(trip)
                try repository.save(trips)
                // 新建的專案立即成為目前使用中的專案。
                repository.saveCurrentTripID(trip.id)
            }
        } catch {
            errorMessageSubject.send("旅程儲存失敗，請再試一次")
            return
        }
        didFinishSubject.send(())
    }
}

// MARK: - TripEditorViewModelOutput

extension TripEditorViewModel: TripEditorViewModelOutput {

    var name: AnyPublisher<String, Never> { nameSubject.eraseToAnyPublisher() }
    var selectedCurrency: AnyPublisher<Currency, Never> { selectedCurrencySubject.eraseToAnyPublisher() }
    var taxDescription: AnyPublisher<String, Never> { taxDescriptionSubject.eraseToAnyPublisher() }
    var isConfirmEnabled: AnyPublisher<Bool, Never> { isConfirmEnabledSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didFinish: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }
}
