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
        viewModel = makeViewModel()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        profileRepository = nil
        imageStore = nil
        repository = nil
        super.tearDown()
    }

    private func makeViewModel() -> ShoppingListViewModel {
        ShoppingListViewModel(
            repository: repository,
            imageStore: imageStore,
            userProfileRepository: profileRepository
        )
    }

    // MARK: - 顯示

    func testViewDidLoadPublishesFormattedItems() {
        var items: [ShoppingListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.productName, "抹茶")
        XCTAssertEqual(items.first?.priceDescription, "100$(含稅)")
        XCTAssertEqual(items.first?.payType, "現金")
    }

    func testItemWithPhotoCarriesImageData() {
        var items: [ShoppingListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.first?.imageData, photoData)
        XCTAssertNil(items.last?.imageData, "沒有照片的項目不應帶資料")
    }

    /// 圖片檔遺失不該讓整個清單讀不出來。
    func testMissingImageFileStillShowsTheItem() {
        imageStore.storedImages = [:]
        var items: [ShoppingListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(items.count, 2)
        XCTAssertNil(items.first?.imageData)
    }

    // MARK: - 總金額

    func testTotalSpendTextSumsEveryPrice() {
        var text: String?
        viewModel.output.totalSpendText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(text, "Angus，你已經花了350$")
    }

    func testTotalSpendTextIsRecalculatedAfterDeletion() {
        var text: String?
        viewModel.output.totalSpendText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: 0)

        XCTAssertEqual(text, "Angus，你已經花了250$", "刪除後要重算，不能累加")
    }

    func testTotalSpendTextIsZeroWhenEveryItemIsDeleted() {
        var text: String?
        viewModel.output.totalSpendText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: 0)
        viewModel.input.deleteItem(at: 0)

        XCTAssertEqual(text, "Angus，你已經花了0$")
    }

    /// 遷移前這裡是 for i in 0...lists.count-1，空陣列會直接崩潰。
    func testEmptyListDoesNotCrashAndShowsZero() {
        repository.storedItems = []
        var text: String?
        viewModel.output.totalSpendText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(text, "Angus，你已經花了0$")
    }

    /// 理論上歡迎頁會確保有稱呼，但 repository 回傳的是 optional，
    /// 沒有稱呼時句子仍須完整。
    func testTotalSpendTextOmitsTheNameWhenNoProfileIsStored() {
        profileRepository.storedProfile = nil
        viewModel = makeViewModel()
        var text: String?
        viewModel.output.totalSpendText.sink { text = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(text, "你已經花了350$")
    }

    // MARK: - 刪除與存檔時機

    func testDeleteDoesNotPersistUntilDoneIsTapped() {
        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: 0)

        XCTAssertEqual(repository.saveCallCount, 0)
        XCTAssertEqual(repository.storedItems.count, 2, "尚未按下 Done，存檔不應變動")

        viewModel.input.doneTapped()

        XCTAssertEqual(repository.saveCallCount, 1)
        XCTAssertEqual(repository.storedItems.map(\.productName), ["咖啡"])
    }

    func testDeleteOutOfRangeIndexIsIgnored() {
        viewModel.input.viewDidLoad()

        viewModel.input.deleteItem(at: 99)
        viewModel.input.deleteItem(at: -1)
        viewModel.input.doneTapped()

        XCTAssertEqual(repository.storedItems.count, 2)
    }

    // MARK: - 圖片清理

    func testDoneRemovesImagesOfDeletedItems() {
        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: 0)
        viewModel.input.doneTapped()

        XCTAssertEqual(imageStore.removedNames, ["photo-1"])
    }

    func testDeletingWithoutTappingDoneKeepsTheImage() {
        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: 0)

        XCTAssertTrue(imageStore.removedNames.isEmpty, "沒按 Done 就不該動到圖片")
    }

    func testImagesAreKeptWhenSaveFails() {
        repository.saveError = StubError.failure

        viewModel.input.viewDidLoad()
        viewModel.input.deleteItem(at: 0)
        viewModel.input.doneTapped()

        XCTAssertTrue(imageStore.removedNames.isEmpty, "存檔失敗時不該刪掉圖片")
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
        viewModel.input.itemSelected(at: 0)

        XCTAssertEqual(request?.index, 0)
        XCTAssertEqual(request?.item.productName, "抹茶")
        XCTAssertEqual(request?.photoData, photoData)
    }

    func testSelectingAnOutOfRangeIndexIsIgnored() {
        var request: ShoppingListEditRequest?
        viewModel.output.editRequest.sink { request = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.itemSelected(at: 99)

        XCTAssertNil(request)
    }

    func testEditUpdatesTheListAndTotalButPersistsOnlyOnDone() {
        var items: [ShoppingListItem] = []
        var total: String?
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)
        viewModel.output.totalSpendText.sink { total = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.itemEdited(at: 0, edit("焙茶", price: 150))

        XCTAssertEqual(items.first?.productName, "焙茶")
        XCTAssertEqual(items.first?.priceDescription, "150$(未稅)")
        XCTAssertEqual(items.first?.payType, "玉山")
        XCTAssertEqual(total, "Angus，你已經花了400$")
        XCTAssertEqual(repository.saveCallCount, 0, "尚未按下 Done，存檔不應變動")

        viewModel.input.doneTapped()

        XCTAssertEqual(repository.storedItems.first?.productName, "焙茶")
        XCTAssertEqual(repository.storedItems.first?.photoURL, "photo-1", "沒換照片就保留原本的檔名")
    }

    func testNewPhotoIsWrittenOnDoneAndReplacesTheOldFile() {
        let newPhoto = Data("new".utf8)

        viewModel.input.viewDidLoad()
        viewModel.input.itemEdited(at: 0, edit("抹茶", price: 100, photo: newPhoto))
        XCTAssertEqual(imageStore.storedImages.count, 1, "按下 Done 前不寫檔")

        viewModel.input.doneTapped()

        let newName = repository.storedItems.first?.photoURL
        XCTAssertNotNil(newName)
        XCTAssertNotEqual(newName, "photo-1")
        XCTAssertEqual(newName.flatMap { imageStore.storedImages[$0] }, newPhoto)
        XCTAssertEqual(imageStore.removedNames, ["photo-1"])
    }

    func testNewPhotoIsShownBeforeDone() {
        var items: [ShoppingListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)
        let newPhoto = Data("new".utf8)

        viewModel.input.viewDidLoad()
        viewModel.input.itemEdited(at: 1, edit("咖啡", price: 250, photo: newPhoto))

        XCTAssertEqual(items.last?.imageData, newPhoto)
    }

    func testNewPhotoIsRemovedWhenSaveFails() {
        repository.saveError = StubError.failure

        viewModel.input.viewDidLoad()
        viewModel.input.itemEdited(at: 0, edit("抹茶", price: 100, photo: Data("new".utf8)))
        viewModel.input.doneTapped()

        XCTAssertEqual(Array(imageStore.storedImages.keys), ["photo-1"], "存檔失敗時新照片不留、舊照片不刪")
    }

        // MARK: - 錯誤

    func testLoadFailureReportsErrorAndShowsEmptyList() {
        repository.loadError = StubError.failure
        var message: String?
        var items: [ShoppingListItem] = []
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(message, "購物清單讀取失敗")
        XCTAssertTrue(items.isEmpty)
    }

    func testSaveFailureReportsErrorAndDoesNotFinish() {
        repository.saveError = StubError.failure
        var didFinish = false
        var message: String?
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.doneTapped()

        XCTAssertFalse(didFinish)
        XCTAssertEqual(message, "購物清單儲存失敗，請再試一次")
    }

    func testDonePublishesDidFinish() {
        var didFinish = false
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.doneTapped()

        XCTAssertTrue(didFinish)
    }
}
