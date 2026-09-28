//
//  ShoppingListViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

final class ShoppingListViewModelTests: XCTestCase {

    private var repository: ShoppingListRepositoryStub!
    private var imageStore: ImageStoreStub!
    private var profileRepository: UserProfileRepositoryStub!
    private var ledgerRepository: FeedbackLedgerRepositoryStub!
    private var viewModel: ShoppingListViewModel!
    private var cancellables: Set<AnyCancellable>!

    private let photoData = Data("photo".utf8)

    override func setUp() {
        super.setUp()
        repository = ShoppingListRepositoryStub(storedItems: [
            ShoppingItem(productName: "抹茶", price: 100, payType: "現金", taxState: "含稅", photoURL: "photo-1"),
            ShoppingItem(productName: "咖啡", price: 250, payType: "信用卡", taxState: "未稅")
        ])
        imageStore = ImageStoreStub(storedImages: ["photo-1": photoData])
        profileRepository = UserProfileRepositoryStub(storedProfile: UserProfile(name: "Angus"))
        ledgerRepository = FeedbackLedgerRepositoryStub()
        viewModel = makeViewModel()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        ledgerRepository = nil
        profileRepository = nil
        imageStore = nil
        repository = nil
        super.tearDown()
    }

    private func makeViewModel() -> ShoppingListViewModel {
        ShoppingListViewModel(
            repository: repository,
            imageStore: imageStore,
            userProfileRepository: profileRepository,
            ledgerRepository: ledgerRepository,
            calendar: Self.taipeiCalendar,
            now: { Self.date(2026, 9, 28, hour: 20) }
        )
    }

    private static let taipeiCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        taipeiCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func item(_ name: String, price: Double, on date: Date?) -> ShoppingItem {
        ShoppingItem(productName: name, price: price, payType: "現金", taxState: "含稅", purchasedAt: date)
    }

    // MARK: - 顯示

    func testViewDidLoadPublishesFormattedItems() {
        var items: [ShoppingListItem] = []
        viewModel.output.sections.sink { items = $0.flatMap(\.items) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.productName, "抹茶")
        XCTAssertEqual(items.first?.amount, "NT$ 100")
        XCTAssertEqual(items.first?.taxState, "含稅")
        XCTAssertEqual(items.first?.payType, "現金")
    }

    func testItemWithPhotoCarriesImageData() {
        var items: [ShoppingListItem] = []
        viewModel.output.sections.sink { items = $0.flatMap(\.items) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.first?.imageData, photoData)
        XCTAssertNil(items.last?.imageData, "沒有照片的項目不應帶資料")
    }

    /// 圖片檔遺失不該讓整個清單讀不出來。
    func testMissingImageFileStillShowsTheItem() {
        imageStore.storedImages = [:]
        var items: [ShoppingListItem] = []
        viewModel.output.sections.sink { items = $0.flatMap(\.items) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.count, 2)
        XCTAssertNil(items.first?.imageData)
    }

    // MARK: - 依日期分區

    func testItemsAreGroupedByDayWithTitleAndSubtotal() {
        repository.storedItems = [
            item("抹茶", price: 100, on: Self.date(2026, 9, 27, hour: 9)),
            item("咖啡", price: 250, on: Self.date(2026, 9, 27, hour: 23)),
            item("拉麵", price: 300, on: Self.date(2026, 9, 28, hour: 0))
        ]
        var sections: [ShoppingListSection] = []
        viewModel.output.sections.sink { sections = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(sections.map(\.title), ["9/27（日）", "9/28（一）"])
        XCTAssertEqual(sections.map(\.subtotal), ["NT$ 350", "NT$ 300"])
        XCTAssertEqual(sections.map { $0.items.map(\.productName) }, [["抹茶", "咖啡"], ["拉麵"]])
    }

    func testItemsWithoutADateShareOneSection() {
        repository.storedItems = [
            item("舊的一", price: 10, on: nil),
            item("舊的二", price: 20, on: nil),
            item("新的", price: 30, on: Self.date(2026, 9, 28))
        ]
        var sections: [ShoppingListSection] = []
        viewModel.output.sections.sink { sections = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(sections.map(\.title), ["較早的紀錄", "9/28（一）"])
        XCTAssertEqual(sections.first?.items.count, 2)
    }

    func testSectionTitleShowsTheYearWhenItIsNotThisYear() {
        repository.storedItems = [item("去年", price: 10, on: Self.date(2025, 12, 31))]
        var sections: [ShoppingListSection] = []
        viewModel.output.sections.sink { sections = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(sections.first?.title, "2025/12/31（三）")
    }

    func testIndexPathInALaterSectionMapsToTheRightItem() {
        repository.storedItems = [
            item("抹茶", price: 100, on: Self.date(2026, 9, 27)),
            item("咖啡", price: 250, on: Self.date(2026, 9, 28)),
            item("拉麵", price: 300, on: Self.date(2026, 9, 28))
        ]
        var request: ShoppingListEditRequest?
        viewModel.output.editRequest.sink { request = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.itemSelected(at: IndexPath(row: 1, section: 1))
        XCTAssertEqual(request?.item.productName, "拉麵")

        viewModel.input.deleteItem(at: IndexPath(row: 0, section: 1))
        XCTAssertEqual(repository.storedItems.map(\.productName), ["抹茶", "拉麵"])
    }

    func testSortOrderStartsOldestFirstAndToggles() {
        var orders: [ShoppingListSortOrder] = []
        viewModel.output.sortOrder.sink { orders.append($0) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.sortOrderToggled()
        viewModel.input.sortOrderToggled()

        XCTAssertEqual(orders, [.oldestFirst, .newestFirst, .oldestFirst])
    }

    func testNewestFirstReversesSectionsAndItemsAndPutsUndatedLast() {
        repository.storedItems = [
            item("舊的", price: 10, on: nil),
            item("抹茶", price: 100, on: Self.date(2026, 9, 27)),
            item("咖啡", price: 250, on: Self.date(2026, 9, 28, hour: 9)),
            item("拉麵", price: 300, on: Self.date(2026, 9, 28, hour: 19))
        ]
        var sections: [ShoppingListSection] = []
        viewModel.output.sections.sink { sections = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.sortOrderToggled()

        XCTAssertEqual(sections.map(\.title), ["9/28（一）", "9/27（日）", "較早的紀錄"])
        XCTAssertEqual(sections.first?.items.map(\.productName), ["拉麵", "咖啡"])
        XCTAssertEqual(repository.saveCallCount, 0, "排序只改顯示，不寫檔")

        viewModel.input.sortOrderToggled()

        XCTAssertEqual(sections.map(\.title), ["較早的紀錄", "9/27（日）", "9/28（一）"])
    }

    func testIndexPathFollowsTheNewestFirstOrder() {
        repository.storedItems = [
            item("抹茶", price: 100, on: Self.date(2026, 9, 27)),
            item("咖啡", price: 250, on: Self.date(2026, 9, 28, hour: 9)),
            item("拉麵", price: 300, on: Self.date(2026, 9, 28, hour: 19))
        ]
        var request: ShoppingListEditRequest?
        viewModel.output.editRequest.sink { request = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.sortOrderToggled()
        viewModel.input.itemSelected(at: IndexPath(row: 0, section: 0))
        XCTAssertEqual(request?.item.productName, "拉麵")

        viewModel.input.itemEdited(at: request!.index, edit("豚骨拉麵", price: 300))
        XCTAssertEqual(repository.storedItems.map(\.productName), ["抹茶", "咖啡", "豚骨拉麵"])

        viewModel.input.deleteItem(at: IndexPath(row: 0, section: 1))
        XCTAssertEqual(repository.storedItems.map(\.productName), ["咖啡", "豚骨拉麵"])
    }

    func testEditKeepsThePurchaseDate() {
        let purchasedAt = Self.date(2026, 9, 27)
        repository.storedItems = [item("抹茶", price: 100, on: purchasedAt)]

        viewModel.input.viewDidLoad()
        viewModel.input.itemEdited(at: 0, edit("焙茶", price: 100))

        XCTAssertEqual(repository.storedItems.first?.purchasedAt, purchasedAt)
    }

    // MARK: - 總金額

    func testTotalSpendTextSumsEveryPrice() {
        var text: String?
        viewModel.output.totalAmount.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(text, "NT$ 350")
    }

    func testTotalSpendTextIsRecalculatedAfterDeletion() {
        var text: String?
        viewModel.output.totalAmount.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: IndexPath(row: 0, section: 0))

        XCTAssertEqual(text, "NT$ 250", "刪除後要重算，不能累加")
    }

    func testTotalSpendTextIsZeroWhenEveryItemIsDeleted() {
        var text: String?
        viewModel.output.totalAmount.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: IndexPath(row: 0, section: 0))
        viewModel.input.deleteItem(at: IndexPath(row: 0, section: 0))

        XCTAssertEqual(text, "NT$ 0")
    }

    /// 遷移前這裡是 for i in 0...lists.count-1，空陣列會直接崩潰。
    func testEmptyListDoesNotCrashAndShowsZero() {
        repository.storedItems = []
        var text: String?
        viewModel.output.totalAmount.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(text, "NT$ 0")
    }

    /// 理論上歡迎頁會確保有稱呼，但 repository 回傳的是 optional，
    /// 沒有稱呼時句子仍須完整。
    func testTotalSummaryOmitsTheNameWhenNoProfileIsStored() {
        profileRepository.storedProfile = nil
        viewModel = makeViewModel()
        var text: String?
        viewModel.output.totalSummary.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(text, "共 2 筆", "沒有稱呼時只顯示筆數")
    }

    // MARK: - 刪除

    func testDeletePersistsImmediately() {
        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: IndexPath(row: 0, section: 0))

        XCTAssertEqual(repository.saveCallCount, 1)
        XCTAssertEqual(repository.storedItems.map(\.productName), ["咖啡"])
    }

    func testDeleteOutOfRangeIndexIsIgnored() {
        viewModel.input.viewDidLoad()

        viewModel.input.deleteItem(at: IndexPath(row: 99, section: 0))
        viewModel.input.deleteItem(at: IndexPath(row: -1, section: 0))

        XCTAssertEqual(repository.saveCallCount, 0)
        XCTAssertEqual(repository.storedItems.count, 2)
    }

    func testDeleteRemovesTheImageOfTheDeletedItem() {
        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: IndexPath(row: 0, section: 0))

        XCTAssertEqual(imageStore.removedNames, ["photo-1"])
    }

    func testDeletingACardPurchaseRefundsItsFeedback() {
        let itemID = UUID()
        let otherID = UUID()
        repository.storedItems[1].id = itemID
        ledgerRepository.storedEntries = [
            FeedbackEntry(id: UUID(), cardID: UUID(), date: Date(), amount: 5, shoppingItemID: itemID),
            FeedbackEntry(id: UUID(), cardID: UUID(), date: Date(), amount: 7, shoppingItemID: otherID)
        ]

        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: IndexPath(row: 1, section: 0))

        XCTAssertEqual(ledgerRepository.storedEntries.map(\.shoppingItemID), [otherID])
    }

    /// 刪除沒存成功，消費還在，回饋也不能退。
    func testFailedDeleteDoesNotRefundFeedback() {
        let itemID = UUID()
        repository.storedItems[0].id = itemID
        repository.saveError = StubError.failure
        ledgerRepository.storedEntries = [
            FeedbackEntry(id: UUID(), cardID: UUID(), date: Date(), amount: 5, shoppingItemID: itemID)
        ]

        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: IndexPath(row: 0, section: 0))

        XCTAssertEqual(ledgerRepository.storedEntries.count, 1)
        XCTAssertEqual(ledgerRepository.saveCallCount, 0)
    }

    func testFailedDeleteKeepsTheItemAndItsImage() {
        repository.saveError = StubError.failure
        var items: [ShoppingListItem] = []
        var message: String?
        viewModel.output.sections.sink { items = $0.flatMap(\.items) }.store(in: &cancellables)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: IndexPath(row: 0, section: 0))

        XCTAssertEqual(items.count, 2, "存檔失敗時清單不該少一筆")
        XCTAssertTrue(imageStore.removedNames.isEmpty, "存檔失敗時不該刪掉圖片")
        XCTAssertEqual(message, "消費紀錄儲存失敗，請再試一次")
    }

    // MARK: - 編輯

    private func edit(_ name: String, price: Double, photo: Data? = nil) -> ItemEdit {
        ItemEdit(
            item: ShoppingItem(productName: name, price: price, payType: "玉山", taxState: "未稅"),
            newPhotoData: photo
        )
    }

    func testSelectingAnItemRequestsTheEditorWithItsPhoto() {
        var request: ShoppingListEditRequest?
        viewModel.output.editRequest.sink { request = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.itemSelected(at: IndexPath(row: 0, section: 0))

        XCTAssertEqual(request?.index, 0)
        XCTAssertEqual(request?.item.productName, "抹茶")
        XCTAssertEqual(request?.photoData, photoData)
    }

    func testSelectingAnOutOfRangeIndexIsIgnored() {
        var request: ShoppingListEditRequest?
        viewModel.output.editRequest.sink { request = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.itemSelected(at: IndexPath(row: 99, section: 0))

        XCTAssertNil(request)
    }

    func testEditPersistsImmediatelyAndUpdatesTheTotal() {
        var items: [ShoppingListItem] = []
        var total: String?
        viewModel.output.sections.sink { items = $0.flatMap(\.items) }.store(in: &cancellables)
        viewModel.output.totalAmount.sink { total = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.itemEdited(at: 0, edit("焙茶", price: 150))

        XCTAssertEqual(items.first?.productName, "焙茶")
        XCTAssertEqual(items.first?.amount, "NT$ 150")
        XCTAssertEqual(items.first?.payType, "玉山")
        XCTAssertEqual(total, "NT$ 400")
        XCTAssertEqual(repository.saveCallCount, 1)
        XCTAssertEqual(repository.storedItems.first?.productName, "焙茶")
        XCTAssertEqual(repository.storedItems.first?.photoURL, "photo-1", "沒換照片就保留原本的檔名")
        XCTAssertTrue(imageStore.removedNames.isEmpty)
    }

    func testNewPhotoIsWrittenOnSaveAndReplacesTheOldFile() {
        var items: [ShoppingListItem] = []
        viewModel.output.sections.sink { items = $0.flatMap(\.items) }.store(in: &cancellables)
        let newPhoto = Data("new".utf8)

        viewModel.input.viewDidLoad()
        viewModel.input.itemEdited(at: 0, edit("抹茶", price: 100, photo: newPhoto))

        let newName = repository.storedItems.first?.photoURL
        XCTAssertNotNil(newName)
        XCTAssertNotEqual(newName, "photo-1")
        XCTAssertEqual(newName.flatMap { imageStore.storedImages[$0] }, newPhoto)
        XCTAssertEqual(imageStore.removedNames, ["photo-1"])
        XCTAssertEqual(items.first?.imageData, newPhoto)
    }

    func testFailedEditKeepsTheOldItemAndPhoto() {
        repository.saveError = StubError.failure
        var items: [ShoppingListItem] = []
        var message: String?
        viewModel.output.sections.sink { items = $0.flatMap(\.items) }.store(in: &cancellables)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.itemEdited(at: 0, edit("焙茶", price: 150, photo: Data("new".utf8)))

        XCTAssertEqual(items.first?.productName, "抹茶", "存檔失敗時畫面維持原本的資料")
        XCTAssertEqual(Array(imageStore.storedImages.keys), ["photo-1"], "存檔失敗時新照片不留、舊照片不刪")
        XCTAssertEqual(message, "消費紀錄儲存失敗，請再試一次")
    }

    // MARK: - 錯誤

    func testLoadFailureReportsErrorAndShowsEmptyList() {
        repository.loadError = StubError.failure
        var message: String?
        var items: [ShoppingListItem] = []
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)
        viewModel.output.sections.sink { items = $0.flatMap(\.items) }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(message, "消費紀錄讀取失敗")
        XCTAssertTrue(items.isEmpty)
    }

    func testDonePublishesDidFinishWithoutSaving() {
        var didFinish = false
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.doneTapped()

        XCTAssertTrue(didFinish)
        XCTAssertEqual(repository.saveCallCount, 0, "變更已即時寫檔，完成不需要再存一次")
    }

    func testTotalSummaryCountsTheItemsAndShowsTheName() {
        var summary: String?
        viewModel.output.totalSummary.sink { summary = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        XCTAssertEqual(summary, "共 2 筆・Angus")

        viewModel.input.deleteItem(at: IndexPath(row: 0, section: 0))
        XCTAssertEqual(summary, "共 1 筆・Angus")
    }
}
