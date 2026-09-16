//
//  CardListViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

struct CardListItem: Equatable {
    let name: String
    let feedbackDescription: String
}

protocol CardListViewModelType {
    var input: CardListViewModelInput { get }
    var output: CardListViewModelOutput { get }
}

protocol CardListViewModelInput {
    func viewDidLoad()
    func deleteCard(at index: Int)
    func finishTapped()
}

protocol CardListViewModelOutput {
    var items: AnyPublisher<[CardListItem], Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didFinish: AnyPublisher<Void, Never> { get }
}

// MARK: - ViewModel

final class CardListViewModel: CardListViewModelType {

    private let repository: CardRepository

    private var cards: [Card] = []

    private let itemsSubject = CurrentValueSubject<[CardListItem], Never>([])
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didFinishSubject = PassthroughSubject<Void, Never>()

    init(repository: CardRepository) {
        self.repository = repository
    }

    var input: CardListViewModelInput { self }
    var output: CardListViewModelOutput { self }

    private func publishItems() {
        itemsSubject.send(cards.map(Self.makeItem))
    }

    private static func makeItem(from card: Card) -> CardListItem {
        CardListItem(
            name: card.name,
            feedbackDescription: "回饋趴數：\(card.percent)％"
        )
    }
}

// MARK: - CardListViewModelInput

extension CardListViewModel: CardListViewModelInput {

    func viewDidLoad() {
        do {
            cards = try repository.load()
        } catch {
            cards = []
            errorMessageSubject.send("信用卡資料讀取失敗")
        }
        publishItems()
    }

    func deleteCard(at index: Int) {
        guard cards.indices.contains(index) else { return }
        cards.remove(at: index)
        publishItems()
    }

    /// 刪除不會立即寫檔，只有按下「編輯完成」才儲存，
    /// 這樣誤刪時可以直接返回而不套用變更。
    func finishTapped() {
        do {
            try repository.save(cards)
        } catch {
            errorMessageSubject.send("信用卡儲存失敗，請再試一次")
            return
        }
        didFinishSubject.send(())
    }
}

// MARK: - CardListViewModelOutput

extension CardListViewModel: CardListViewModelOutput {

    var items: AnyPublisher<[CardListItem], Never> { itemsSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didFinish: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }
}
