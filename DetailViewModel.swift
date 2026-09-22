//
//  DetailViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

/// 付款方式。
///
/// 遷移前這裡只有 `list.payType` 一個字串，而選了信用卡之後那個字串會被改寫成
/// **卡片名稱**，所以 `list.payType == "信用卡"` 永遠不成立 —— 這就是舊程式碼裡
/// 「理由未知，先用是否出現信用卡選項做判定」的真正原因。
/// 現在把「付款方式」與「要存進檔案的字串」分成兩件事，判定就不需要看畫面狀態了。
enum PayMethod: Equatable {
    case cash
    case card(index: Int?)

    var isCard: Bool {
        if case .card = self { return true }
        return false
    }

    var selectedCardIndex: Int? {
        if case .card(let index) = self { return index }
        return nil
    }
}

struct CardMenuItem: Equatable {
    let title: String
}

enum DetailRoute: Equatable {
    case addCard
    case shoppingList
    /// 商品已加入清單。清單頁不能返回，只能按「完成」回到首頁。
    case savedToShoppingList
}

protocol DetailViewModelType {
    var input: DetailViewModelInput { get }
    var output: DetailViewModelOutput { get }
}

protocol DetailViewModelInput {
    func viewDidLoad()
    func reloadCards()
    func productNameChanged(_ text: String)
    func payMethodSelected(row: Int)
    func cardSelected(at index: Int)
    func addCardTapped()
    func photoSelected(_ data: Data?)
    func saveTapped()
    func showShoppingListTapped()
}

protocol DetailViewModelOutput {
    /// 大字金額，例如「NT$ 516」。
    var priceAmount: AnyPublisher<String, Never> { get }
    /// 金額下方的稅別，例如「含稅」。
    var priceTaxState: AnyPublisher<String, Never> { get }
    /// 商品名稱是必填，沒填時「加入消費紀錄」顯示為停用，而不是按了沒反應。
    var isSaveEnabled: AnyPublisher<Bool, Never> { get }
    var isCardSectionVisible: AnyPublisher<Bool, Never> { get }
    /// 信用卡按鈕的主要文字：卡名與回饋率。
    var cardButtonTitle: AnyPublisher<String, Never> { get }
    /// 信用卡按鈕的第二行：剩餘回饋額度。尚未選卡時為空字串。
    var cardButtonSubtitle: AnyPublisher<String, Never> { get }
    var cardMenuItems: AnyPublisher<[CardMenuItem], Never> { get }
    var feedbackText: AnyPublisher<String, Never> { get }
    var route: AnyPublisher<DetailRoute, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
}

// MARK: - ViewModel

final class DetailViewModel: DetailViewModelType {

    private enum Constants {
        /// 回饋趴數要先扣掉的基礎趴數。
        static let baseFeedbackPercent = 1.5
        static let cardButtonPlaceholder = "請選擇信用卡"
        static let feedbackPlaceholder = "選擇信用卡後顯示回饋金額"
    }

    private let cardRepository: CardRepository
    private let shoppingListRepository: ShoppingListRepository
    private let imageStore: ImageStore

    private var item: ShoppingItem
    private var cards: [Card] = []
    private var payMethod: PayMethod = .cash
    private var photoData: Data?

    private let priceAmountSubject = CurrentValueSubject<String, Never>("")
    private let priceTaxStateSubject = CurrentValueSubject<String, Never>("")
    private let isSaveEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let isCardSectionVisibleSubject = CurrentValueSubject<Bool, Never>(false)
    private let cardButtonTitleSubject = CurrentValueSubject<String, Never>(Constants.cardButtonPlaceholder)
    private let cardMenuItemsSubject = CurrentValueSubject<[CardMenuItem], Never>([])
    private let cardButtonSubtitleSubject = CurrentValueSubject<String, Never>("")
    private let feedbackTextSubject = CurrentValueSubject<String, Never>(Constants.feedbackPlaceholder)
    private let routeSubject = PassthroughSubject<DetailRoute, Never>()
    private let errorMessageSubject = PassthroughSubject<String, Never>()

    init(
        item: ShoppingItem,
        cardRepository: CardRepository,
        shoppingListRepository: ShoppingListRepository,
        imageStore: ImageStore
    ) {
        self.item = item
        self.cardRepository = cardRepository
        self.shoppingListRepository = shoppingListRepository
        self.imageStore = imageStore
        // 畫面上的 picker 預設停在「現金」，所以付款方式的初始值也是現金。
        self.item.payType = "現金"
    }

    var input: DetailViewModelInput { self }
    var output: DetailViewModelOutput { self }

    // MARK: - Private

    private func loadCards() {
        do {
            cards = try cardRepository.load()
        } catch {
            cards = []
            errorMessageSubject.send("信用卡資料讀取失敗")
        }
        cardMenuItemsSubject.send(cards.map { CardMenuItem(title: "\($0.name) \($0.percent)%") })
    }

    /// 卡片清單變動後，先前選到的索引就不再可信，一律回到未選取狀態。
    private func resetCardSelection() {
        if payMethod.isCard {
            payMethod = .card(index: nil)
        }
        cardButtonTitleSubject.send(Constants.cardButtonPlaceholder)
        cardButtonSubtitleSubject.send("")
        feedbackTextSubject.send(Constants.feedbackPlaceholder)
    }

    private func feedbackMoney(for card: Card) -> Double {
        Self.roundedToCents((card.percent - Constants.baseFeedbackPercent) * item.price * 0.01)
    }

    /// 從目前的剩餘額度扣掉這一筆的回饋，而不是從上限扣：每一筆消費都要累積扣減。
    /// 額度用完後停在 0，不會變成負數。
    private func persistSelectedCardFeedback() {
        guard let index = payMethod.selectedCardIndex, cards.indices.contains(index) else { return }
        let remaining = cards[index].feedbackRemaining - cards[index].feedbackMoney
        cards[index].feedbackRemaining = Self.roundedToCents(max(0, remaining))
        try? cardRepository.save(cards)
    }

    /// 回饋金額是浮點相乘相減的結果，不取到分位就會存進
    /// 999.3629999999999 這種值，並在每次消費後持續累積誤差。
    private static func roundedToCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

// MARK: - DetailViewModelInput

extension DetailViewModel: DetailViewModelInput {

    func viewDidLoad() {
        priceAmountSubject.send(PriceText.twd(item.price))
        priceTaxStateSubject.send(item.taxState)
        loadCards()
    }

    func reloadCards() {
        loadCards()
        resetCardSelection()
    }

    func productNameChanged(_ text: String) {
        isSaveEnabledSubject.send(!text.trimmingCharacters(in: .whitespaces).isEmpty)
        item.productName = text
    }

    func payMethodSelected(row: Int) {
        if row == 0 {
            payMethod = .cash
            item.payType = "現金"
            isCardSectionVisibleSubject.send(false)
        } else {
            payMethod = .card(index: nil)
            item.payType = "信用卡"
            isCardSectionVisibleSubject.send(true)
        }
    }

    func cardSelected(at index: Int) {
        guard cards.indices.contains(index) else { return }

        payMethod = .card(index: index)
        // 存進清單的是卡片名稱，不是「信用卡」三個字。
        item.payType = cards[index].name
        cards[index].feedbackMoney = feedbackMoney(for: cards[index])

        cardButtonTitleSubject.send("\(cards[index].name) \(cards[index].percent)%")
        cardButtonSubtitleSubject.send("剩餘回饋 \(PriceText.twd(cards[index].feedbackRemaining))")
        feedbackTextSubject.send("這筆回饋 \(PriceText.twd(cards[index].feedbackMoney))")
    }

    func addCardTapped() {
        routeSubject.send(.addCard)
    }

    func photoSelected(_ data: Data?) {
        photoData = data
    }

    func saveTapped() {
        guard !item.productName.isEmpty else { return }

        if let photoData {
            item.photoURL = try? imageStore.save(photoData)
        }

        do {
            var items = try shoppingListRepository.load()
            items.append(item)
            try shoppingListRepository.save(items)
        } catch {
            errorMessageSubject.send("消費紀錄儲存失敗，請再試一次")
            return
        }

        // 紀錄確定存進去才扣回饋額度。剩餘額度是累積扣減的，
        // 沒存成功或沒填名稱就先扣，重按一次就會再扣一次。
        if payMethod.isCard {
            persistSelectedCardFeedback()
        }

        routeSubject.send(.savedToShoppingList)
    }

    func showShoppingListTapped() {
        routeSubject.send(.shoppingList)
    }
}

// MARK: - DetailViewModelOutput

extension DetailViewModel: DetailViewModelOutput {

    var priceAmount: AnyPublisher<String, Never> { priceAmountSubject.eraseToAnyPublisher() }
    var priceTaxState: AnyPublisher<String, Never> { priceTaxStateSubject.eraseToAnyPublisher() }
    var isSaveEnabled: AnyPublisher<Bool, Never> { isSaveEnabledSubject.eraseToAnyPublisher() }
    var isCardSectionVisible: AnyPublisher<Bool, Never> { isCardSectionVisibleSubject.eraseToAnyPublisher() }
    var cardButtonTitle: AnyPublisher<String, Never> { cardButtonTitleSubject.eraseToAnyPublisher() }
    var cardButtonSubtitle: AnyPublisher<String, Never> { cardButtonSubtitleSubject.eraseToAnyPublisher() }
    var cardMenuItems: AnyPublisher<[CardMenuItem], Never> { cardMenuItemsSubject.eraseToAnyPublisher() }
    var feedbackText: AnyPublisher<String, Never> { feedbackTextSubject.eraseToAnyPublisher() }
    var route: AnyPublisher<DetailRoute, Never> { routeSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
}
