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
    private var viewModel: DetailViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cardRepository = CardRepositoryStub(storedCards: [
            Card(name: "A卡", percent: 3.5, limit: 5000, feedbackRemaining: 5000, id: cardAID),
            Card(name: "B卡", percent: 5, limit: 2000, feedbackRemaining: 2000, id: UUID())
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

        XCTAssertEqual(items.map(\.title), ["A卡 3.5%", "B卡 5.0%"])
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

    func testCardSelectionCalculatesFeedbackMoney() {
        var text: String?
        viewModel.output.feedbackText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)

        // (3.5 - 1.5) * 1000 * 0.01 = 20
        XCTAssertEqual(text, "這筆回饋 NT$ 20")
    }

    /// 按鈕分成兩行：卡名與回饋率在上，剩餘額度在下。
    func testCardButtonShowsTheCardAndItsRemainingFeedback() {
        var title: String?
        var subtitle: String?
        viewModel.output.cardButtonTitle.sink { title = $0 }.store(in: &cancellables)
        viewModel.output.cardButtonSubtitle.sink { subtitle = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)

        XCTAssertEqual(title, "A卡 3.5%")
        XCTAssertEqual(subtitle, "剩餘回饋 NT$ 5,000")
    }

    private func entry(_ amount: Double, cardID: UUID? = nil) -> FeedbackEntry {
        FeedbackEntry(id: UUID(), cardID: cardID ?? cardAID, date: Date(), amount: amount, shoppingItemID: nil)
    }

    private func buyMatchaWithCardA() {
        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()
    }

    func testSavingRecordsAFeedbackEntryForTheItem() {
        buyMatchaWithCardA()

        let saved = listRepository.storedItems.first
        XCTAssertEqual(ledgerRepository.storedEntries.count, 1)
        XCTAssertEqual(ledgerRepository.storedEntries.first?.cardID, cardAID)
        XCTAssertEqual(ledgerRepository.storedEntries.first?.amount, 20)
        XCTAssertEqual(ledgerRepository.storedEntries.first?.shoppingItemID, saved?.id)
        XCTAssertEqual(cardRepository.saveCallCount, 0, "剩餘額度改由明細算出，不再改寫卡片")
    }

    /// 剩餘額度是明細的加總，每一筆消費都會累積扣減。
    func testRemainingFeedbackAccumulatesAcrossPurchases() {
        ledgerRepository.storedEntries = [entry(20)]
        var subtitle: String?
        viewModel.output.cardButtonSubtitle.sink { subtitle = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)

        XCTAssertEqual(subtitle, "剩餘回饋 NT$ 4,980")
    }

    func testEntriesOfOtherCardsDoNotCount() {
        ledgerRepository.storedEntries = [entry(300, cardID: UUID())]
        var subtitle: String?
        viewModel.output.cardButtonSubtitle.sink { subtitle = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)

        XCTAssertEqual(subtitle, "剩餘回饋 NT$ 5,000")
    }

    /// 額度只剩 5 元時，這筆最多只拿到 5 元，剩餘停在 0。
    func testFeedbackIsLimitedByTheRemainingAmount() {
        ledgerRepository.storedEntries = [entry(4995)]
        var text: String?
        viewModel.output.feedbackText.sink { text = $0 }.store(in: &cancellables)

        buyMatchaWithCardA()

        XCTAssertEqual(text, "這筆回饋 NT$ 5")
        XCTAssertEqual(ledgerRepository.storedEntries.last?.amount, 5)
        XCTAssertEqual(cardRepository.storedCards[0].remainingFeedback(in: ledgerRepository.storedEntries), 0)
    }

    func testNoEntryIsRecordedWhenTheCardIsUsedUp() {
        ledgerRepository.storedEntries = [entry(5000)]

        buyMatchaWithCardA()

        XCTAssertEqual(ledgerRepository.storedEntries.count, 1)
    }

    /// 趴數低於 1.5 時算出來是負的，不能反過來把額度加回去。
    func testARateBelowTheFeeGivesNoFeedback() {
        cardRepository.storedCards = [Card(name: "低趴卡", percent: 1, limit: 100, feedbackRemaining: 100, id: cardAID)]
        var text: String?
        viewModel.output.feedbackText.sink { text = $0 }.store(in: &cancellables)

        buyMatchaWithCardA()

        XCTAssertEqual(text, "這筆回饋 NT$ 0")
        XCTAssertTrue(ledgerRepository.storedEntries.isEmpty)
    }

    /// 沒填名稱時不會存入紀錄，也就不能記回饋，否則每按一次就多記一次。
    func testSaveWithoutANameDoesNotRecordFeedback() {
        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)
        viewModel.input.saveTapped()
        viewModel.input.saveTapped()

        XCTAssertEqual(ledgerRepository.saveCallCount, 0)
    }

    func testFailedSaveDoesNotRecordFeedback() {
        listRepository.saveError = StubError.failure

        buyMatchaWithCardA()

        XCTAssertEqual(ledgerRepository.saveCallCount, 0, "紀錄沒存成功，不該記回饋")
    }

    /// 0.1% * 637 元會算出 0.6370000000000006，不取到分位就會存進檔案並持續累積。
    func testFeedbackIsRoundedToCents() {
        cardRepository.storedCards = [Card(name: "C卡", percent: 1.6, limit: 1000, feedbackRemaining: 1000, id: cardAID)]
        viewModel = DetailViewModel(
            item: ShoppingItem(productName: "", price: 637, payType: "", taxState: "未稅"),
            cardRepository: cardRepository,
            shoppingListRepository: listRepository,
            imageStore: imageStore,
            ledgerRepository: ledgerRepository
        )

        buyMatchaWithCardA()

        XCTAssertEqual(ledgerRepository.storedEntries.first?.amount, 0.64)
        XCTAssertEqual(cardRepository.storedCards[0].remainingFeedback(in: ledgerRepository.storedEntries), 999.36)
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
        cardRepository.storedCards = [Card(name: "C卡", percent: 1, limit: 100, feedbackRemaining: 100)]
        viewModel.input.reloadCards()

        XCTAssertEqual(items.map(\.title), ["C卡 1.0%"])
    }
}
