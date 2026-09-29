//
//  DetailViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

final class DetailViewModelTests: XCTestCase {

    private var cardRepository: CardRepositoryStub!
    private var listRepository: ShoppingListRepositoryStub!
    private var imageStore: ImageStoreStub!
    private var ledgerRepository: FeedbackLedgerRepositoryStub!
    private let cardAID = UUID()
    private let planAID = UUID()
    private var viewModel: DetailViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cardRepository = CardRepositoryStub(storedCards: [
            Card.withPlan(name: "A卡", rate: 3.5, cap: 5000, id: cardAID, planID: planAID),
            Card.withPlan(name: "B卡", rate: 5, cap: 2000)
        ])
        ledgerRepository = FeedbackLedgerRepositoryStub()
        listRepository = ShoppingListRepositoryStub()
        imageStore = ImageStoreStub()
        viewModel = makeViewModel()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        ledgerRepository = nil
        imageStore = nil
        listRepository = nil
        cardRepository = nil
        super.tearDown()
    }

    private func makeViewModel(price: Double = 1000, taxState: String = "未稅") -> DetailViewModel {
        DetailViewModel(
            item: ShoppingItem(productName: "", price: price, payType: "", taxState: taxState),
            cardRepository: cardRepository,
            shoppingListRepository: listRepository,
            imageStore: imageStore,
            ledgerRepository: ledgerRepository
        )
    }

    // MARK: - 初始顯示

    func testPriceIsShownAsALargeAmountWithItsTaxState() {
        var amount: String?
        var taxState: String?
        viewModel.output.priceAmount.sink { amount = $0 }.store(in: &cancellables)
        viewModel.output.priceTaxState.sink { taxState = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(amount, "NT$ 1,000")
        XCTAssertEqual(taxState, "未稅")
    }

    /// 商品名稱是必填，沒填時按鈕停用，而不是按了沒反應。
    func testSaveIsDisabledUntilTheProductHasAName() {
        var isEnabled: Bool?
        viewModel.output.isSaveEnabled.sink { isEnabled = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        XCTAssertEqual(isEnabled, false)

        viewModel.input.productNameChanged("抹茶")
        XCTAssertEqual(isEnabled, true)

        viewModel.input.productNameChanged("   ")
        XCTAssertEqual(isEnabled, false)
    }

    func testCardSectionIsHiddenInitially() {
        var isVisible = true
        viewModel.output.isCardSectionVisible.sink { isVisible = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertFalse(isVisible)
    }

    func testCardMenuListsEveryStoredCard() {
        var items: [CardMenuItem] = []
        viewModel.output.cardMenuItems.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.map(\.title), ["A卡 3.5%", "B卡 5%"])
    }

    // MARK: - 付款方式

    func testSelectingCreditCardShowsTheCardSection() {
        var isVisible = false
        viewModel.output.isCardSectionVisible.sink { isVisible = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)

        XCTAssertTrue(isVisible)
    }

    func testSelectingCashHidesTheCardSection() {
        var isVisible = true
        viewModel.output.isCardSectionVisible.sink { isVisible = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.payMethodSelected(row: 0)

        XCTAssertFalse(isVisible)
    }

    /// 沒有碰過 picker 時，付款方式應與畫面上預選的「現金」一致。
    func testPayTypeDefaultsToCash() {
        viewModel.input.viewDidLoad()
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(listRepository.storedItems.first?.payType, "現金")
    }

    /// 這是舊程式碼「理由未知」的真正原因：選了卡片之後 payType 會變成卡片名稱，
    /// 所以拿它跟「信用卡」比對永遠不成立。
    func testSelectingACardStoresTheCardNameAsPayType() {
        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(listRepository.storedItems.first?.payType, "A卡")
    }

    // MARK: - 回饋計算

    private func entry(base: Double, bonus: Double = 0, planID: UUID? = nil) -> FeedbackEntry {
        FeedbackEntry(
            id: UUID(), cardID: cardAID, date: Date(), amount: base + bonus, shoppingItemID: nil,
            planID: planID ?? planAID, baseAmount: base, bonusAmount: bonus
        )
    }

    private func selectCardA() {
        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)
    }

    private func buyMatchaWithCardA(qualifies: Bool = false) {
        selectCardA()
        if qualifies {
            viewModel.input.bonusQualificationChanged(true)
        }
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()
    }

    /// 回饋以毛額顯示，海外手續費另外列出：3.5% × 1000 = 35，1.5% × 1000 = 15。
    func testFeedbackShowsTheGrossAmountAndTheFeeSeparately() {
        var text: String?
        viewModel.output.feedbackText.sink { text = $0 }.store(in: &cancellables)

        selectCardA()

        XCTAssertEqual(text, "這筆回饋 NT$ 35\n海外手續費 NT$ 15")
    }

    /// 按鈕分成兩行：卡名與回饋率在上，剩餘額度在下。剩餘只是估算，所以寫「約」。
    func testCardButtonShowsTheCardAndItsRemainingFeedback() {
        var title: String?
        var subtitle: String?
        viewModel.output.cardButtonTitle.sink { title = $0 }.store(in: &cancellables)
        viewModel.output.cardButtonSubtitle.sink { subtitle = $0 }.store(in: &cancellables)

        selectCardA()

        XCTAssertEqual(title, "A卡 3.5%")
        XCTAssertEqual(subtitle, "剩餘回饋約 NT$ 5,000")
    }

    func testAnUncappedPlanSaysSo() {
        cardRepository.storedCards = [Card.withPlan(name: "Richart", rate: 3.3, cap: nil, id: cardAID)]
        var subtitle: String?
        viewModel.output.cardButtonSubtitle.sink { subtitle = $0 }.store(in: &cancellables)

        selectCardA()

        XCTAssertEqual(subtitle, "回饋無上限")
    }

    func testSavingRecordsAFeedbackEntryForTheItem() {
        buyMatchaWithCardA()

        let saved = listRepository.storedItems.first
        let recorded = ledgerRepository.storedEntries.first
        XCTAssertEqual(ledgerRepository.storedEntries.count, 1)
        XCTAssertEqual(recorded?.cardID, cardAID)
        XCTAssertEqual(recorded?.planID, planAID)
        XCTAssertEqual(recorded?.baseAmount, 35)
        XCTAssertEqual(recorded?.bonusAmount, 0)
        XCTAssertEqual(recorded?.amount, 35)
        XCTAssertEqual(recorded?.shoppingItemID, saved?.id)
        XCTAssertEqual(cardRepository.saveCallCount, 0, "剩餘額度由明細算出，不改寫卡片")
    }

    /// 剩餘額度是這個方案所有明細的加總，每一筆消費都會累積扣減。
    func testRemainingFeedbackAccumulatesAcrossPurchases() {
        ledgerRepository.storedEntries = [entry(base: 35)]
        var subtitle: String?
        viewModel.output.cardButtonSubtitle.sink { subtitle = $0 }.store(in: &cancellables)

        selectCardA()

        XCTAssertEqual(subtitle, "剩餘回饋約 NT$ 4,965")
    }

    func testEntriesOfOtherPlansDoNotCount() {
        ledgerRepository.storedEntries = [entry(base: 300, planID: UUID())]
        var subtitle: String?
        viewModel.output.cardButtonSubtitle.sink { subtitle = $0 }.store(in: &cancellables)

        selectCardA()

        XCTAssertEqual(subtitle, "剩餘回饋約 NT$ 5,000")
    }

    /// 額度只剩 5 元時，這筆最多只拿到 5 元，剩餘停在 0。
    func testFeedbackIsLimitedByTheRemainingAmount() {
        ledgerRepository.storedEntries = [entry(base: 4995)]
        var text: String?
        viewModel.output.feedbackText.sink { text = $0 }.store(in: &cancellables)

        buyMatchaWithCardA()

        XCTAssertEqual(text, "這筆回饋 NT$ 5\n海外手續費 NT$ 15")
        XCTAssertEqual(ledgerRepository.storedEntries.last?.baseAmount, 5)
    }

    func testNoEntryIsRecordedWhenThePlanIsUsedUp() {
        ledgerRepository.storedEntries = [entry(base: 5000)]

        buyMatchaWithCardA()

        XCTAssertEqual(ledgerRepository.storedEntries.count, 1)
    }

    /// 沒填名稱時不會存入紀錄，也就不能記回饋，否則每按一次就多記一次。
    func testSaveWithoutANameDoesNotRecordFeedback() {
        selectCardA()
        viewModel.input.saveTapped()
        viewModel.input.saveTapped()

        XCTAssertEqual(ledgerRepository.saveCallCount, 0)
    }

    func testFailedSaveDoesNotRecordFeedback() {
        listRepository.saveError = StubError.failure

        buyMatchaWithCardA()

        XCTAssertEqual(ledgerRepository.saveCallCount, 0, "紀錄沒存成功，不該記回饋")
    }

    /// 1.6% × 637 元會算出 10.192，不取到分位就會存進檔案並持續累積。
    func testFeedbackIsRoundedToCents() {
        cardRepository.storedCards = [Card.withPlan(name: "C卡", rate: 1.6, cap: 1000, id: cardAID, planID: planAID)]
        viewModel = DetailViewModel(
            item: ShoppingItem(productName: "", price: 637, payType: "", taxState: "未稅"),
            cardRepository: cardRepository,
            shoppingListRepository: listRepository,
            imageStore: imageStore,
            ledgerRepository: ledgerRepository
        )

        buyMatchaWithCardA()

        XCTAssertEqual(ledgerRepository.storedEntries.first?.baseAmount, 10.19)
    }

    // MARK: - 方案與加碼

    private let bonus = CardPlan.Bonus(rate: 6, cap: 50, label: "指定店家")

    private func useBonusCard() {
        cardRepository.storedCards = [
            Card.withPlan(name: "熊本熊", rate: 2.5, cap: nil, bonus: bonus, id: cardAID, planID: planAID)
        ]
    }

    func testABonusPlanShowsTheSwitchOff() {
        useBonusCard()
        var state: BonusSwitchState?
        var title: String?
        viewModel.output.bonusSwitch.sink { state = $0 }.store(in: &cancellables)
        viewModel.output.cardButtonTitle.sink { title = $0 }.store(in: &cancellables)

        selectCardA()

        XCTAssertEqual(state, BonusSwitchState(title: "符合加碼（指定店家）", isOn: false))
        XCTAssertEqual(title, "熊本熊 2.5%＋6%")
    }

    func testAPlanWithoutBonusHidesTheSwitch() {
        var state: BonusSwitchState? = BonusSwitchState(title: "", isOn: true)
        viewModel.output.bonusSwitch.sink { state = $0 }.store(in: &cancellables)

        selectCardA()

        XCTAssertNil(state)
    }

    /// 2.5% × 1000 = 25；符合加碼再加 6% = 60，但加碼上限 50。
    func testQualifyingAddsTheBonusUpToItsCap() {
        useBonusCard()
        var text: String?
        viewModel.output.feedbackText.sink { text = $0 }.store(in: &cancellables)

        selectCardA()
        XCTAssertEqual(text, "這筆回饋 NT$ 25\n海外手續費 NT$ 15", "預設不算加碼")

        viewModel.input.bonusQualificationChanged(true)
        XCTAssertEqual(text, "這筆回饋 NT$ 75\n海外手續費 NT$ 15")
    }

    func testTheBonusIsRecordedSeparately() {
        useBonusCard()

        buyMatchaWithCardA(qualifies: true)

        let recorded = ledgerRepository.storedEntries.first
        XCTAssertEqual(recorded?.baseAmount, 25)
        XCTAssertEqual(recorded?.bonusAmount, 50)
        XCTAssertEqual(recorded?.amount, 75)
    }

    func testTheBonusCapIsSharedAcrossPurchases() {
        useBonusCard()
        ledgerRepository.storedEntries = [entry(base: 25, bonus: 40)]
        var subtitle: String?
        viewModel.output.cardButtonSubtitle.sink { subtitle = $0 }.store(in: &cancellables)

        buyMatchaWithCardA(qualifies: true)

        XCTAssertEqual(subtitle, "加碼剩餘約 NT$ 10")
        XCTAssertEqual(ledgerRepository.storedEntries.last?.bonusAmount, 10)
    }

    /// 換方案時開關回到關閉，不會把上一張卡的「符合加碼」帶過去。
    func testChoosingAnotherPlanTurnsTheSwitchOff() {
        cardRepository.storedCards = [
            Card.withPlan(name: "熊本熊", rate: 2.5, cap: nil, bonus: bonus, id: cardAID, planID: planAID),
            Card.withPlan(name: "另一張", rate: 2, cap: nil, bonus: bonus)
        ]
        var state: BonusSwitchState?
        viewModel.output.bonusSwitch.sink { state = $0 }.store(in: &cancellables)

        selectCardA()
        viewModel.input.bonusQualificationChanged(true)
        viewModel.input.cardSelected(at: 1)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(state?.isOn, false)
        XCTAssertEqual(ledgerRepository.storedEntries.first?.bonusAmount, 0)
    }

    /// 有週期的上限只算這一期，文字也說明是哪一期。
    func testAMonthlyBonusCapShowsThisMonthsRemaining() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 12))!
        let lastMonth = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20))!
        cardRepository.storedCards = [
            Card.withPlan(
                name: "熊本熊", rate: 2.5, cap: nil,
                bonus: CardPlan.Bonus(rate: 6, cap: 50, label: "指定店家", capPeriod: .calendarMonth),
                id: cardAID, planID: planAID
            )
        ]
        ledgerRepository.storedEntries = [
            FeedbackEntry(id: UUID(), cardID: cardAID, date: lastMonth, amount: 50, shoppingItemID: nil,
                          planID: planAID, baseAmount: 0, bonusAmount: 50)
        ]
        viewModel = DetailViewModel(
            item: ShoppingItem(productName: "", price: 1000, payType: "", taxState: "未稅"),
            cardRepository: cardRepository, shoppingListRepository: listRepository, imageStore: imageStore,
            ledgerRepository: ledgerRepository, now: { now }, calendar: calendar
        )
        var subtitle: String?
        var text: String?
        viewModel.output.cardButtonSubtitle.sink { subtitle = $0 }.store(in: &cancellables)
        viewModel.output.feedbackText.sink { text = $0 }.store(in: &cancellables)

        selectCardA()
        viewModel.input.bonusQualificationChanged(true)

        XCTAssertEqual(subtitle, "本月加碼剩餘約 NT$ 50", "上個月用掉的不算")
        XCTAssertEqual(text, "這筆回饋 NT$ 75\n海外手續費 NT$ 15")
    }

    /// 多方案的卡片每個方案各佔一項，存進清單的付款方式包含方案名稱。
    func testEachPlanOfASwitchableCardIsItsOwnMenuItem() {
        let travel = CardPlan(id: UUID(), name: "玩旅刷", baseRate: 3.3, baseCap: nil, bonus: nil, note: "")
        let holiday = CardPlan(id: UUID(), name: "假日刷", baseRate: 2, baseCap: nil, bonus: nil, note: "")
        cardRepository.storedCards = [
            Card(name: "Richart", percent: 3.3, limit: 0, feedbackRemaining: 0, id: cardAID, plans: [travel, holiday])
        ]
        var items: [CardMenuItem] = []
        viewModel.output.cardMenuItems.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 1)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(items.map(\.title), ["Richart・玩旅刷 3.3%", "Richart・假日刷 2%"])
        XCTAssertEqual(listRepository.storedItems.first?.payType, "Richart・假日刷")
        XCTAssertEqual(ledgerRepository.storedEntries.first?.planID, holiday.id)
        XCTAssertEqual(ledgerRepository.storedEntries.first?.baseAmount, 20)
    }

    func testCashPurchaseDoesNotTouchCards() {
        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 0)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(cardRepository.saveCallCount, 0)
        XCTAssertEqual(ledgerRepository.saveCallCount, 0)
    }

    /// 遷移前若選了信用卡卻沒選卡片就按儲存，會以 -1 索引存取陣列而崩潰。
    func testChoosingCreditCardWithoutPickingACardDoesNotCrash() {
        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.productNameChanged("抹茶")

        viewModel.input.saveTapped()

        XCTAssertEqual(cardRepository.saveCallCount, 0)
        XCTAssertEqual(listRepository.storedItems.count, 1)
    }

    func testSelectingAnOutOfRangeCardIsIgnored() {
        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)

        viewModel.input.cardSelected(at: 99)

        XCTAssertEqual(cardRepository.saveCallCount, 0)
    }

    // MARK: - 儲存

    func testSaveAppendsItemToTheExistingList() {
        listRepository.storedItems = [
            ShoppingItem(productName: "舊項目", price: 50, payType: "現金", taxState: "含稅")
        ]

        viewModel.input.viewDidLoad()
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(listRepository.storedItems.map(\.productName), ["舊項目", "抹茶"])
    }

    func testSaveStampsThePurchaseDate() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        viewModel = DetailViewModel(
            item: ShoppingItem(productName: "", price: 1000, payType: "", taxState: "未稅"),
            cardRepository: cardRepository,
            shoppingListRepository: listRepository,
            imageStore: imageStore,
            ledgerRepository: ledgerRepository,
            now: { now }
        )

        viewModel.input.viewDidLoad()
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(listRepository.storedItems.last?.purchasedAt, now)
        XCTAssertNotNil(listRepository.storedItems.last?.id, "新的消費一存檔就有識別碼")
    }

    func testSaveIsIgnoredWhenProductNameIsEmpty() {
        var routes: [DetailRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.saveTapped()

        XCTAssertEqual(listRepository.saveCallCount, 0)
        XCTAssertTrue(routes.isEmpty)
    }

    func testSaveRoutesToTheShoppingList() {
        var routes: [DetailRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(routes, [.savedToShoppingList])
    }

    func testSaveFailureReportsErrorAndDoesNotNavigate() {
        listRepository.saveError = StubError.failure
        var routes: [DetailRoute] = []
        var message: String?
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertTrue(routes.isEmpty)
        XCTAssertEqual(message, "消費紀錄儲存失敗，請再試一次")
    }

    // MARK: - 照片

    func testSelectedPhotoIsStoredAndReferencedByName() {
        let data = Data("photo".utf8)

        viewModel.input.viewDidLoad()
        viewModel.input.photoSelected(data)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        let photoName = listRepository.storedItems.first?.photoURL
        XCTAssertNotNil(photoName)
        XCTAssertEqual(imageStore.storedImages[photoName ?? ""], data)
    }

    func testItemWithoutAPhotoHasNoPhotoReference() {
        viewModel.input.viewDidLoad()
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertNil(listRepository.storedItems.first?.photoURL)
    }

    // MARK: - 導航與卡片重載

    func testAddCardAndShoppingListEmitRoutes() {
        var routes: [DetailRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.addCardTapped()
        viewModel.input.showShoppingListTapped()

        XCTAssertEqual(routes, [.addCard, .shoppingList])
    }

    /// 從信用卡畫面返回後，先前選到的索引可能已經失效，必須回到未選取狀態。
    func testReloadCardsResetsTheSelection() {
        var title: String?
        viewModel.output.cardButtonTitle.sink { title = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)

        cardRepository.storedCards = []
        viewModel.input.reloadCards()

        XCTAssertEqual(title, "請選擇信用卡")

        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()
        XCTAssertEqual(ledgerRepository.saveCallCount, 0, "卡片已不存在，不該再記回饋")
    }

    func testReloadCardsRefreshesTheMenu() {
        var items: [CardMenuItem] = []
        viewModel.output.cardMenuItems.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        cardRepository.storedCards = [Card.withPlan(name: "C卡", rate: 1, cap: 100)]
        viewModel.input.reloadCards()

        XCTAssertEqual(items.map(\.title), ["C卡 1%"])
    }
}
