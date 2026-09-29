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

/// 「符合加碼」開關。選中的方案沒有加碼時不顯示。
struct BonusSwitchState: Equatable {
    /// 例如「符合加碼（指定店家）」。
    let title: String
    let isOn: Bool
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
    /// `index` 是選單中的位置；多方案的卡片每個方案各佔一項。
    func cardSelected(at index: Int)
    /// 使用者勾選或取消「符合加碼」。
    func bonusQualificationChanged(_ qualifies: Bool)
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
    /// nil 代表選中的方案沒有加碼，開關隱藏。
    var bonusSwitch: AnyPublisher<BonusSwitchState?, Never> { get }
    /// 兩行：「這筆回饋 NT$ 35」與「海外手續費 NT$ 15」。
    var feedbackText: AnyPublisher<String, Never> { get }
    var route: AnyPublisher<DetailRoute, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
}

// MARK: - ViewModel

final class DetailViewModel: DetailViewModelType {

    /// 選單中的一項：哪張卡的哪個方案。
    private struct PlanOption {
        let cardIndex: Int
        let planIndex: Int
    }

    private enum Constants {
        static let cardButtonPlaceholder = "請選擇信用卡"
        static let feedbackPlaceholder = "選擇信用卡後顯示回饋金額"
    }

    private let cardRepository: CardRepository
    private let shoppingListRepository: ShoppingListRepository
    private let imageStore: ImageStore
    private let ledgerRepository: FeedbackLedgerRepository
    private let now: () -> Date
    /// 上限週期以這個曆法與時區切分。
    private let calendar: Calendar

    private var item: ShoppingItem
    private var cards: [Card] = []
    /// 回饋明細，用來算每個方案的剩餘額度。
    private var entries: [FeedbackEntry] = []
    /// 選單中的每一項，對應 `cardMenuItems`。
    private var options: [PlanOption] = []
    /// 這筆是否符合加碼。每次進入畫面與換方案時都回到關閉，估算不會高估。
    private var qualifiesForBonus = false
    private var payMethod: PayMethod = .cash
    private var photoData: Data?

    private let priceAmountSubject = CurrentValueSubject<String, Never>("")
    private let priceTaxStateSubject = CurrentValueSubject<String, Never>("")
    private let isSaveEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let isCardSectionVisibleSubject = CurrentValueSubject<Bool, Never>(false)
    private let cardButtonTitleSubject = CurrentValueSubject<String, Never>(Constants.cardButtonPlaceholder)
    private let cardMenuItemsSubject = CurrentValueSubject<[CardMenuItem], Never>([])
    private let bonusSwitchSubject = CurrentValueSubject<BonusSwitchState?, Never>(nil)
    private let cardButtonSubtitleSubject = CurrentValueSubject<String, Never>("")
    private let feedbackTextSubject = CurrentValueSubject<String, Never>(Constants.feedbackPlaceholder)
    private let routeSubject = PassthroughSubject<DetailRoute, Never>()
    private let errorMessageSubject = PassthroughSubject<String, Never>()

    init(
        item: ShoppingItem,
        cardRepository: CardRepository,
        shoppingListRepository: ShoppingListRepository,
        imageStore: ImageStore,
        ledgerRepository: FeedbackLedgerRepository,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.item = item
        self.cardRepository = cardRepository
        self.shoppingListRepository = shoppingListRepository
        self.imageStore = imageStore
        self.ledgerRepository = ledgerRepository
        self.now = now
        self.calendar = calendar
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
        entries = (try? ledgerRepository.load()) ?? []
        // 不在回饋期間內的方案（已到期或尚未開始）不列出；一個方案都不剩的卡片就整張不出現。
        let today = now()
        options = cards.indices.flatMap { cardIndex in
            (cards[cardIndex].plans ?? []).indices
                .filter { cards[cardIndex].plans?[$0].isActive(on: today, calendar: calendar) == true }
                .map { PlanOption(cardIndex: cardIndex, planIndex: $0) }
        }
        cardMenuItemsSubject.send(options.map { CardMenuItem(title: menuTitle(for: $0)) })
    }

    /// 卡片清單變動後，先前選到的索引就不再可信，一律回到未選取狀態。
    private func resetCardSelection() {
        if payMethod.isCard {
            payMethod = .card(index: nil)
        }
        qualifiesForBonus = false
        bonusSwitchSubject.send(nil)
        cardButtonTitleSubject.send(Constants.cardButtonPlaceholder)
        cardButtonSubtitleSubject.send("")
        feedbackTextSubject.send(Constants.feedbackPlaceholder)
    }

    private func card(of option: PlanOption) -> Card { cards[option.cardIndex] }

    private func plan(of option: PlanOption) -> CardPlan {
        cards[option.cardIndex].plans?[option.planIndex] ?? CardPlan(
            id: UUID(), name: "", baseRate: 0, baseCap: nil, bonus: nil, note: ""
        )
    }

    /// 只有一個方案的卡片只顯示卡名；多方案的卡片加上方案名，例如「Richart・玩旅刷」。
    private func displayName(for option: PlanOption) -> String {
        let card = card(of: option)
        guard (card.plans?.count ?? 0) > 1 else { return card.name }
        return "\(card.name)・\(plan(of: option).name)"
    }

    /// 例如「Richart・玩旅刷 3.3%」、「熊本熊 2.5%＋6%」。
    private func menuTitle(for option: PlanOption) -> String {
        let plan = plan(of: option)
        var rate = "\(PriceText.amount(plan.baseRate))%"
        if let bonus = plan.bonus {
            rate += "＋\(PriceText.amount(bonus.rate))%"
        }
        return "\(displayName(for: option)) \(rate)"
    }

    private var selectedOption: PlanOption? {
        guard let index = payMethod.selectedCardIndex, options.indices.contains(index) else { return nil }
        return options[index]
    }

    private func quote(for option: PlanOption, entries: [FeedbackEntry]) -> FeedbackQuote {
        FeedbackCalculator.quote(
            plan: plan(of: option), price: item.price, qualifiesForBonus: qualifiesForBonus, entries: entries,
            closingDay: card(of: option).statementClosingDay, at: now(), calendar: calendar
        )
    }

    /// 剩餘額度只是估算：銀行以請款入帳日認定期別，App 只知道刷卡日。
    /// 有週期的上限只算這一期，例如「本月加碼剩餘約 NT$ 320」。
    private func remainingText(for option: PlanOption) -> String {
        let plan = plan(of: option)
        let closingDay = card(of: option).statementClosingDay
        var parts: [String] = []
        if let remaining = FeedbackCalculator.remainingBase(
            of: plan, in: entries, closingDay: closingDay, at: now(), calendar: calendar
        ) {
            let prefix = (plan.baseCapPeriod ?? .campaign).currentPrefix
            parts.append("\(prefix)剩餘回饋約 \(PriceText.twd(remaining))")
        }
        if let remaining = FeedbackCalculator.remainingBonus(
            of: plan, in: entries, closingDay: closingDay, at: now(), calendar: calendar
        ) {
            let prefix = (plan.bonus?.capPeriod ?? .campaign).currentPrefix
            parts.append("\(prefix)加碼剩餘約 \(PriceText.twd(remaining))")
        }
        return parts.isEmpty ? "回饋無上限" : parts.joined(separator: "・")
    }

    private func publishFeedback(for option: PlanOption) {
        let quote = quote(for: option, entries: entries)
        // 手續費另起一行，數字不會被斷在兩行中間。
        feedbackTextSubject.send("這筆回饋 \(PriceText.twd(quote.total))\n海外手續費 \(PriceText.twd(quote.fee))")
    }

    /// 在回饋明細加一筆，剩餘額度由明細加總算出，所以會跨消費累積扣減。
    /// 重新讀一次明細再加，避免覆蓋掉進入這頁之後別處寫入的明細。
    private func recordSelectedPlanFeedback(for itemID: UUID?) {
        guard let option = selectedOption, let cardID = card(of: option).id else { return }
        var latest = (try? ledgerRepository.load()) ?? entries
        let quote = quote(for: option, entries: latest)
        guard quote.total > 0 else { return }
        latest.append(
            FeedbackEntry(
                id: UUID(), cardID: cardID, date: item.purchasedAt ?? now(), amount: quote.total,
                shoppingItemID: itemID, planID: plan(of: option).id,
                baseAmount: quote.base, bonusAmount: quote.bonus
            )
        )
        guard (try? ledgerRepository.save(latest)) != nil else { return }
        entries = latest
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
        // 切回信用卡時要重新選卡，加碼開關也跟著收起。
        qualifiesForBonus = false
        bonusSwitchSubject.send(nil)
    }

    func cardSelected(at index: Int) {
        guard options.indices.contains(index) else { return }
        let option = options[index]
        let plan = plan(of: option)

        payMethod = .card(index: index)
        // 存進清單的是卡片（與方案）名稱，不是「信用卡」三個字。
        item.payType = displayName(for: option)
        qualifiesForBonus = false
        bonusSwitchSubject.send(plan.bonus.map { bonus in
            let condition = bonus.label.isEmpty ? "" : "（\(bonus.label)）"
            return BonusSwitchState(title: "符合加碼\(condition)", isOn: false)
        })

        cardButtonTitleSubject.send(menuTitle(for: option))
        cardButtonSubtitleSubject.send(remainingText(for: option))
        publishFeedback(for: option)
    }

    func bonusQualificationChanged(_ qualifies: Bool) {
        guard let option = selectedOption, plan(of: option).bonus != nil else { return }
        qualifiesForBonus = qualifies
        publishFeedback(for: option)
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
        // 消費紀錄依這個日期分區。
        item.purchasedAt = now()
        if item.id == nil {
            item.id = UUID()
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
            recordSelectedPlanFeedback(for: item.id)
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
    var bonusSwitch: AnyPublisher<BonusSwitchState?, Never> { bonusSwitchSubject.eraseToAnyPublisher() }
    var feedbackText: AnyPublisher<String, Never> { feedbackTextSubject.eraseToAnyPublisher() }
    var route: AnyPublisher<DetailRoute, Never> { routeSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
}
