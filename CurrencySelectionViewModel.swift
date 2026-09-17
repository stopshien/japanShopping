//
//  CurrencySelectionViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

protocol CurrencySelectionViewModelType {
    var input: CurrencySelectionViewModelInput { get }
    var output: CurrencySelectionViewModelOutput { get }
}

protocol CurrencySelectionViewModelInput {
    func currencySelected(_ currency: Currency)
    func confirmTapped()
}

protocol CurrencySelectionViewModelOutput {
    var selectedCurrency: AnyPublisher<Currency, Never> { get }
    var currencyDescription: AnyPublisher<String, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didFinish: AnyPublisher<Void, Never> { get }
}

// MARK: - ViewModel

/// 引導流程的第二步。名字由上一步帶進來，這裡才把完整設定寫入。
final class CurrencySelectionViewModel: CurrencySelectionViewModelType {

    private let name: String
    private let repository: UserProfileRepository
    private var currency: Currency

    private let selectedCurrencySubject: CurrentValueSubject<Currency, Never>
    private let currencyDescriptionSubject: CurrentValueSubject<String, Never>
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didFinishSubject = PassthroughSubject<Void, Never>()

    init(name: String, repository: UserProfileRepository, initialCurrency: Currency = .japaneseYen) {
        self.name = name
        self.repository = repository
        self.currency = initialCurrency
        self.selectedCurrencySubject = CurrentValueSubject(initialCurrency)
        self.currencyDescriptionSubject = CurrentValueSubject(Self.describe(initialCurrency))
    }

    var input: CurrencySelectionViewModelInput { self }
    var output: CurrencySelectionViewModelOutput { self }

    /// 說明該幣別會套用的稅率，讓使用者知道選擇的後果。
    private static func describe(_ currency: Currency) -> String {
        let rates = TaxCategory.allCases
            .map { "\($0.title) \(currency.taxPercent(for: $0))%" }
            .joined(separator: "、")
        return currency.hasReducedTaxRate
            ? "稅率：\(rates)，可於每筆消費切換"
            : "稅率：\(currency.taxPercent(for: .standard))%"
    }
}

// MARK: - CurrencySelectionViewModelInput

extension CurrencySelectionViewModel: CurrencySelectionViewModelInput {

    func currencySelected(_ currency: Currency) {
        guard currency != self.currency else { return }
        self.currency = currency
        selectedCurrencySubject.send(currency)
        currencyDescriptionSubject.send(Self.describe(currency))
    }

    func confirmTapped() {
        do {
            try repository.save(UserProfile(name: name, currency: currency))
        } catch {
            errorMessageSubject.send("設定儲存失敗，請再試一次")
            return
        }
        didFinishSubject.send(())
    }
}

// MARK: - CurrencySelectionViewModelOutput

extension CurrencySelectionViewModel: CurrencySelectionViewModelOutput {

    var selectedCurrency: AnyPublisher<Currency, Never> { selectedCurrencySubject.eraseToAnyPublisher() }
    var currencyDescription: AnyPublisher<String, Never> { currencyDescriptionSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didFinish: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }
}
