//
//  CardSetViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

protocol CardSetViewModelType {
    var input: CardSetViewModelInput { get }
    var output: CardSetViewModelOutput { get }
}

protocol CardSetViewModelInput {
    func nameChanged(_ text: String)
    func percentChanged(_ text: String)
    func limitChanged(_ text: String)
    func addTapped()
}

protocol CardSetViewModelOutput {
    var isAddEnabled: AnyPublisher<Bool, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didAddCard: AnyPublisher<Void, Never> { get }
}

// MARK: - Errors

enum CardSetError: LocalizedError, Equatable {
    case invalidPercent
    case invalidLimit
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidPercent:
            return "回饋趴數請輸入數字"
        case .invalidLimit:
            return "回饋上限請輸入數字"
        case .saveFailed:
            return "信用卡儲存失敗，請再試一次"
        }
    }
}

// MARK: - ViewModel

final class CardSetViewModel: CardSetViewModelType {

    private let repository: CardRepository

    private var name = ""
    private var percentText = ""
    private var limitText = ""

    private let isAddEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didAddCardSubject = PassthroughSubject<Void, Never>()

    init(repository: CardRepository) {
        self.repository = repository
    }

    var input: CardSetViewModelInput { self }
    var output: CardSetViewModelOutput { self }

    /// 三個欄位都不可為空，與遷移前的判斷一致。
    private func refreshAddEnabled() {
        let isFilled = !name.isEmpty && !percentText.isEmpty && !limitText.isEmpty
        isAddEnabledSubject.send(isFilled)
    }
}

// MARK: - CardSetViewModelInput

extension CardSetViewModel: CardSetViewModelInput {

    func nameChanged(_ text: String) {
        name = text.trimmingCharacters(in: .whitespaces)
        refreshAddEnabled()
    }

    func percentChanged(_ text: String) {
        percentText = text.trimmingCharacters(in: .whitespaces)
        refreshAddEnabled()
    }

    func limitChanged(_ text: String) {
        limitText = text.trimmingCharacters(in: .whitespaces)
        refreshAddEnabled()
    }

    func addTapped() {
        guard isAddEnabledSubject.value else { return }

        guard let percent = Double(percentText) else {
            errorMessageSubject.send(CardSetError.invalidPercent.localizedDescription)
            return
        }
        guard let limit = Double(limitText) else {
            errorMessageSubject.send(CardSetError.invalidLimit.localizedDescription)
            return
        }

        // 新卡的回饋剩餘額度等於上限，已回饋金額為 0。
        let card = Card(name: name, percent: percent, limit: limit, feedbackRemaining: limit)

        do {
            var cards = try repository.load()
            cards.append(card)
            try repository.save(cards)
            didAddCardSubject.send(())
        } catch {
            errorMessageSubject.send(CardSetError.saveFailed.localizedDescription)
        }
    }
}

// MARK: - CardSetViewModelOutput

extension CardSetViewModel: CardSetViewModelOutput {

    var isAddEnabled: AnyPublisher<Bool, Never> { isAddEnabledSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didAddCard: AnyPublisher<Void, Never> { didAddCardSubject.eraseToAnyPublisher() }
}
