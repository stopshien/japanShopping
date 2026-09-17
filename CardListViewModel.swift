//
//  CardListViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

struct CardListItem: Equatable {
    let name: String
    /// 回饋趴數，顯示為徽章（例如 "3.5%"）。
    let percentBadge: String
    /// 上限與剩餘額度，這頁最常被回頭查的資訊。
    let limitDescription: String
}

enum CardListRoute: Equatable {
    case createCard
}

protocol CardListViewModelType {
    var input: CardListViewModelInput { get }
    var output: CardListViewModelOutput { get }
}

protocol CardListViewModelInput {
    func viewDidLoad()
    func createTapped()
    /// 從新增卡片頁返回後呼叫。
    func reloadAfterAddingCard()
    func deleteCard(at index: Int)
    func finishTapped()
}

protocol CardListViewModelOutput {
    var items: AnyPublisher<[CardListItem], Never> { get }
    var route: AnyPublisher<CardListRoute, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didFinish: AnyPublisher<Void, Never> { get }
}

// MARK: - ViewModel

final class CardListViewModel: CardListViewModelType {

    private let repository: CardRepository

    private var cards: [Card] = []
    /// 進入畫面時的快照，用來分辨「新加入的卡片」與「使用者刪掉的卡片」。
    private var loadedCards: [Card] = []

    private let itemsSubject = CurrentValueSubject<[CardListItem], Never>([])
    private let routeSubject = PassthroughSubject<CardListRoute, Never>()
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
            percentBadge: "\(PriceText.amount(card.percent))%",
            limitDescription: "上限 \(PriceText.amount(card.limit))　剩餘 \(PriceText.amount(card.feedbackRemaining))"
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
        loadedCards = cards
        publishItems()
    }

    func createTapped() {
        routeSubject.send(.createCard)
    }

    /// 只把新出現的卡片加進來，不重載整份清單 ——
    /// 否則使用者在這頁做過但尚未按下「完成」的刪除會被沖掉。
    func reloadAfterAddingCard() {
        let stored = (try? repository.load()) ?? []
        let added = stored.filter { card in !loadedCards.contains(card) }
        guard !added.isEmpty else { return }

        cards.append(contentsOf: added)
        loadedCards.append(contentsOf: added)
        publishItems()
    }

    func deleteCard(at index: Int) {
        guard cards.indices.contains(index) else { return }
        cards.remove(at: index)
        publishItems()
    }

    /// 刪除不會立即寫檔，只有按下「完成」才儲存，
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
    var route: AnyPublisher<CardListRoute, Never> { routeSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didFinish: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }
}
