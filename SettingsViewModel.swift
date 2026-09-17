//
//  SettingsViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

protocol SettingsViewModelType {
    var input: SettingsViewModelInput { get }
    var output: SettingsViewModelOutput { get }
}

protocol SettingsViewModelInput {
    func viewDidLoad()
    func nameChanged(_ text: String)
    func currencySelected(_ currency: Currency)
    func saveTapped()
}

protocol SettingsViewModelOutput {
    var name: AnyPublisher<String, Never> { get }
    var selectedCurrency: AnyPublisher<Currency, Never> { get }
    var isSaveEnabled: AnyPublisher<Bool, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didFinish: AnyPublisher<Void, Never> { get }
}

// MARK: - ViewModel

final class SettingsViewModel: SettingsViewModelType {

    private let repository: UserProfileRepository
    private var currentName = ""
    private var currency: Currency = .japaneseYen

    private let nameSubject = CurrentValueSubject<String, Never>("")
    private let selectedCurrencySubject = CurrentValueSubject<Currency, Never>(.japaneseYen)
    private let isSaveEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didFinishSubject = PassthroughSubject<Void, Never>()

    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    var input: SettingsViewModelInput { self }
    var output: SettingsViewModelOutput { self }
}

// MARK: - SettingsViewModelInput

extension SettingsViewModel: SettingsViewModelInput {

    func viewDidLoad() {
        guard let profile = repository.load() else { return }
        currentName = profile.name
        currency = profile.currency
        nameSubject.send(profile.name)
        selectedCurrencySubject.send(profile.currency)
        isSaveEnabledSubject.send(!profile.name.isEmpty)
    }

    func nameChanged(_ text: String) {
        currentName = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaveEnabledSubject.send(!currentName.isEmpty)
    }

    func currencySelected(_ currency: Currency) {
        self.currency = currency
        selectedCurrencySubject.send(currency)
    }

    func saveTapped() {
        guard !currentName.isEmpty else { return }

        do {
            try repository.save(UserProfile(name: currentName, currency: currency))
        } catch {
            errorMessageSubject.send("設定儲存失敗，請再試一次")
            return
        }
        didFinishSubject.send(())
    }
}

// MARK: - SettingsViewModelOutput

extension SettingsViewModel: SettingsViewModelOutput {

    var name: AnyPublisher<String, Never> { nameSubject.eraseToAnyPublisher() }
    var selectedCurrency: AnyPublisher<Currency, Never> { selectedCurrencySubject.eraseToAnyPublisher() }
    var isSaveEnabled: AnyPublisher<Bool, Never> { isSaveEnabledSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didFinish: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }
}
