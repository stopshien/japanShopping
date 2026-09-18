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
    private var viewModel: DetailViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cardRepository = CardRepositoryStub(storedCards: [
            Card(name: "A卡", percent: 3.5, limit: 5000, feedbackRemaining: 5000),
            Card(name: "B卡", percent: 5, limit: 2000, feedbackRemaining: 2000)
        ])
        listRepository = ShoppingListRepositoryStub()
        imageStore = ImageStoreStub()
        viewModel = makeViewModel()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
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
            imageStore: imageStore
        )
    }

    // MARK: - 初始顯示

    func testPriceDescriptionShowsPriceAndTaxState() {
        var text: String?
        viewModel.output.priceDescription.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(text, "價格：1000$ (未稅)")
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
        XCTAssertEqual(text, "回饋金額為：20.00")
    }

    func testCardButtonTitleShowsRemainingFeedback() {
        var title: String?
        viewModel.output.cardButtonTitle.sink { title = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)

        XCTAssertEqual(title, "A卡卡 剩餘5000元")
    }

    func testSavingUpdatesRemainingFeedbackOnTheSelectedCard() {
        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        // 5000 - 20 = 4980
        XCTAssertEqual(cardRepository.storedCards.first?.feedbackRemaining, 4980)
        XCTAssertEqual(cardRepository.storedCards.first?.feedbackMoney, 20)
    }

    /// 剩餘額度要從目前的剩餘扣，不是從上限扣。遷移前每一筆都從上限重算，
    /// 刷第二次以後剩餘額度就只反映最新一筆。
    func testRemainingFeedbackAccumulatesAcrossPurchases() {
        cardRepository.storedCards = [Card(name: "A卡", percent: 3.5, limit: 5000, feedbackRemaining: 4980)]

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        // 已剩 4980，這筆 1000 元回饋 20，應剩 4960（舊算法會存成 5000 - 20 = 4980）
        XCTAssertEqual(cardRepository.storedCards.first?.feedbackRemaining, 4960)
    }

    func testRemainingFeedbackStopsAtZero() {
        cardRepository.storedCards = [Card(name: "A卡", percent: 3.5, limit: 5000, feedbackRemaining: 5)]

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(cardRepository.storedCards.first?.feedbackRemaining, 0)
    }

    /// 沒填名稱時不會存入紀錄，也就不能扣回饋，否則每按一次就多扣一次。
    func testSaveWithoutANameDoesNotDeductFeedback() {
        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)
        viewModel.input.saveTapped()
        viewModel.input.saveTapped()

        XCTAssertEqual(cardRepository.saveCallCount, 0)
        XCTAssertEqual(cardRepository.storedCards.first?.feedbackRemaining, 5000)
    }

    func testFailedSaveDoesNotDeductFeedback() {
        listRepository.saveError = StubError.failure

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(cardRepository.saveCallCount, 0, "紀錄沒存成功，不該扣回饋")
    }

    /// 0.1% * 637 元會算出 0.6370000000000006，不取到分位就會存進檔案並持續累積。
    func testFeedbackIsRoundedToCents() {
        cardRepository.storedCards = [Card(name: "C卡", percent: 1.6, limit: 1000, feedbackRemaining: 1000)]
        viewModel = DetailViewModel(
            item: ShoppingItem(productName: "", price: 637, payType: "", taxState: "未稅"),
            cardRepository: cardRepository,
            shoppingListRepository: listRepository,
            imageStore: imageStore
        )

        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 1)
        viewModel.input.cardSelected(at: 0)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(cardRepository.storedCards.first?.feedbackMoney, 0.64)
        XCTAssertEqual(cardRepository.storedCards.first?.feedbackRemaining, 999.36)
    }

    func testCashPurchaseDoesNotTouchCards() {
        viewModel.input.viewDidLoad()
        viewModel.input.payMethodSelected(row: 0)
        viewModel.input.productNameChanged("抹茶")
        viewModel.input.saveTapped()

        XCTAssertEqual(cardRepository.saveCallCount, 0)
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

    func testAddCardAndEditCardsEmitRoutes() {
        var routes: [DetailRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.addCardTapped()
        viewModel.input.editCardsTapped()
        viewModel.input.showShoppingListTapped()

        XCTAssertEqual(routes, [.addCard, .editCards, .shoppingList])
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
        XCTAssertEqual(cardRepository.saveCallCount, 0, "卡片已不存在，不該再寫入回饋")
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
