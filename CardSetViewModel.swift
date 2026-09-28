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

/// 編輯時帶入欄位的初始文字。
struct CardSetPrefill: Equatable {
    let name: String
    let percent: String
    let limit: String
}

protocol CardSetViewModelOutput {
    /// 「新增信用卡」或「編輯信用卡」。
    var title: String { get }
    /// 送出按鈕的文字。
    var confirmTitle: String { get }
    /// 編輯時的初始欄位，新增時為 nil。
    var prefill: CardSetPrefill? { get }
    var isAddEnabled: AnyPublisher<Bool, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    /// 新增或編輯存檔成功。
    var didSave: AnyPublisher<Void, Never> { get }
}

// MARK: - Errors

enum CardSetError: LocalizedError, Equatable {
    case invalidPercent
    case invalidLimit
    case saveFailed
    case cardNotFound

    var errorDescription: String? {
        switch self {
        case .invalidPercent:
            return "回饋趴數請輸入數字"
        case .invalidLimit:
            return "回饋上限請輸入數字"
        case .saveFailed:
            return "信用卡儲存失敗，請再試一次"
        case .cardNotFound:
            return "找不到這張信用卡，可能已被刪除"
        }
    }
}

// MARK: - ViewModel

final class CardSetViewModel: CardSetViewModelType {

    private let repository: CardRepository
    /// 編輯中的卡片；nil 代表新增。
    private let editingCard: Card?

    private var name = ""
    private var percentText = ""
    private var limitText = ""

    private let isAddEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didSaveSubject = PassthroughSubject<Void, Never>()

    let prefill: CardSetPrefill?

    init(editingCard: Card? = nil, repository: CardRepository) {
        self.repository = repository
        self.editingCard = editingCard
        if let editingCard {
            let prefill = CardSetPrefill(
                name: editingCard.name,
                percent: PriceText.amount(editingCard.percent),
                limit: PriceText.amount(editingCard.limit)
            )
            self.prefill = prefill
            name = prefill.name
            percentText = prefill.percent
            limitText = prefill.limit
            isAddEnabledSubject.send(true)
        } else {
            prefill = nil
        }
    }

    var input: CardSetViewModelInput { self }
    var output: CardSetViewModelOutput { self }

    /// 有 id 就以 id 比對；遷移前的卡片沒有 id，只能比對整張卡。
    private static func isSameCard(_ lhs: Card, _ rhs: Card) -> Bool {
        if let id = rhs.id { return lhs.id == id }
        return lhs == rhs
    }

    /// 剩餘額度由回饋明細算出，改上限後自然是「新上限 − 已用」。
    /// 舊欄位 `feedbackRemaining` 仍依同樣規則更新，只是讓尚未轉成明細的舊卡保持一致。
    /// 趴數只影響之後的消費，已存的紀錄不會重算。
    private static func edited(_ card: Card, name: String, percent: Double, limit: Double) -> Card {
        let used = max(0, card.limit - card.feedbackRemaining)
        let remaining = (max(0, limit - used) * 100).rounded() / 100
        return Card(name: name, percent: percent, limit: limit, feedbackRemaining: remaining, id: card.id)
    }

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

        do {
            var cards = try repository.load()
            if let editingCard {
                guard let index = cards.firstIndex(where: { Self.isSameCard($0, editingCard) }) else {
                    errorMessageSubject.send(CardSetError.cardNotFound.localizedDescription)
                    return
                }
                cards[index] = Self.edited(cards[index], name: name, percent: percent, limit: limit)
            } else {
                // 新卡的回饋剩餘額度等於上限，已回饋金額為 0。
                cards.append(Card(name: name, percent: percent, limit: limit, feedbackRemaining: limit, id: UUID()))
            }
            try repository.save(cards)
            didSaveSubject.send(())
        } catch {
            errorMessageSubject.send(CardSetError.saveFailed.localizedDescription)
        }
    }
}

// MARK: - CardSetViewModelOutput

extension CardSetViewModel: CardSetViewModelOutput {

    var title: String { editingCard == nil ? "新增信用卡" : "編輯信用卡" }
    var confirmTitle: String { editingCard == nil ? "新增信用卡" : "儲存" }
    var isAddEnabled: AnyPublisher<Bool, Never> { isAddEnabledSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didSave: AnyPublisher<Void, Never> { didSaveSubject.eraseToAnyPublisher() }
}
