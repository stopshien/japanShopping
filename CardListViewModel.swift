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
    case editCard(Card)
}

protocol CardListViewModelType {
    var input: CardListViewModelInput { get }
    var output: CardListViewModelOutput { get }
}

protocol CardListViewModelInput {
    func viewDidLoad()
    func createTapped()
    func cardSelected(at index: Int)
    /// 從新增或編輯卡片頁存檔後呼叫。
    func reloadAfterCardSaved()
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
    private let ledgerRepository: FeedbackLedgerRepository

    private var cards: [Card] = []
    /// 回饋明細，用來算剩餘額度。
    private var entries: [FeedbackEntry] = []
    /// 進入畫面時的快照，用來分辨「新加入的卡片」與「使用者刪掉的卡片」。
    private var loadedCards: [Card] = []

    private let itemsSubject = CurrentValueSubject<[CardListItem], Never>([])
    private let routeSubject = PassthroughSubject<CardListRoute, Never>()
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didFinishSubject = PassthroughSubject<Void, Never>()

    init(repository: CardRepository, ledgerRepository: FeedbackLedgerRepository) {
        self.repository = repository
        self.ledgerRepository = ledgerRepository
    }

    var input: CardListViewModelInput { self }
    var output: CardListViewModelOutput { self }

    private func publishItems() {
        itemsSubject.send(cards.map(makeItem))
    }

    private func makeItem(from card: Card) -> CardListItem {
        let remaining = card.remainingFeedback(in: entries)
        return CardListItem(
            name: card.name,
            percentBadge: "\(PriceText.amount(card.percent))%",
            limitDescription: "上限 \(PriceText.amount(card.limit))　剩餘 \(PriceText.amount(remaining))"
        )
    }

    /// 已刪除的卡片，它的明細也一併移除，不留下對不到卡片的資料。
    private func removeEntriesOfDeletedCards() {
        let cardIDs = Set(cards.compactMap(\.id))
        let kept = entries.filter { cardIDs.contains($0.cardID) }
        guard kept.count != entries.count, (try? ledgerRepository.save(kept)) != nil else { return }
        entries = kept
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
        entries = (try? ledgerRepository.load()) ?? []
        loadedCards = cards
        publishItems()
    }

    func createTapped() {
        routeSubject.send(.createCard)
    }

    func cardSelected(at index: Int) {
        guard cards.indices.contains(index) else { return }
        routeSubject.send(.editCard(cards[index]))
    }

    /// 只套用新增或編輯過的卡片，不重載整份清單 ——
    /// 否則使用者在這頁做過但尚未按下「完成」的刪除會被沖掉。
    func reloadAfterCardSaved() {
        let stored = (try? repository.load()) ?? []
        var changed = false

        for card in stored where !loadedCards.contains(card) {
            if let id = card.id, let index = loadedCards.firstIndex(where: { $0.id == id }) {
                // 編輯過的卡片：已刪除的就維持刪除，否則換成新的內容。
                loadedCards[index] = card
                if let current = cards.firstIndex(where: { $0.id == id }) {
                    cards[current] = card
                }
            } else {
                cards.append(card)
                loadedCards.append(card)
            }
            changed = true
        }

        if changed {
            publishItems()
        }
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
        removeEntriesOfDeletedCards()
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
