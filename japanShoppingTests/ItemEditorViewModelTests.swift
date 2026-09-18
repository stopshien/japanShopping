//
//  ItemEditorViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

final class ItemEditorViewModelTests: XCTestCase {

    private var cardRepository: CardRepositoryStub!
    private var cancellables: Set<AnyCancellable>!

    private let item = ShoppingItem(
        productName: "抹茶", price: 200, payType: "現金", taxState: "未稅", photoURL: "photo-1"
    )

    override func setUp() {
        super.setUp()
        cardRepository = CardRepositoryStub(storedCards: [
            Card(name: "玉山", percent: 3, limit: 1000)
        ])
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        cardRepository = nil
        super.tearDown()
    }

    private func makeViewModel(item: ShoppingItem? = nil, photoData: Data? = nil) -> ItemEditorViewModel {
        ItemEditorViewModel(item: item ?? self.item, photoData: photoData, cardRepository: cardRepository)
    }

    private func capturedEdit(from viewModel: ItemEditorViewModel) -> () -> ItemEdit? {
        var edit: ItemEdit?
        viewModel.output.didSave.sink { edit = $0 }.store(in: &cancellables)
        return { edit }
    }

    // MARK: - 初始值

    func testShowsTheCurrentValues() {
        let viewModel = makeViewModel()
        var name: String?
        var price: String?
        var mode: TaxMode??
        var payType: String?
        viewModel.output.productName.sink { name = $0 }.store(in: &cancellables)
        viewModel.output.priceText.sink { price = $0 }.store(in: &cancellables)
        viewModel.output.selectedTaxMode.sink { mode = $0 }.store(in: &cancellables)
        viewModel.output.payTypeTitle.sink { payType = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(name, "抹茶")
        XCTAssertEqual(price, "200")
        XCTAssertEqual(mode, .some(.excludingTax))
        XCTAssertEqual(payType, "現金")
    }

    func testPayTypeOptionsAreCashAndCards() {
        let viewModel = makeViewModel()
        var options: [String] = []
        viewModel.output.payTypeOptions.sink { options = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(options, ["現金", "玉山"])
    }

    /// 卡片已刪除時，原本的付款方式仍要能保留，不能被默默換成別的。
    func testKeepsAPayTypeThatIsNoLongerAnOption() {
        var old = item
        old.payType = "已刪除的卡"
        let viewModel = makeViewModel(item: old)
        var options: [String] = []
        viewModel.output.payTypeOptions.sink { options = $0 }.store(in: &cancellables)
        let edit = capturedEdit(from: viewModel)

        viewModel.input.viewDidLoad()
        viewModel.input.saveTapped()

        XCTAssertEqual(options, ["現金", "玉山", "已刪除的卡"])
        XCTAssertEqual(edit()?.item.payType, "已刪除的卡")
    }

    // MARK: - 儲存

    func testSavingCarriesEveryEditedField() {
        let viewModel = makeViewModel()
        let edit = capturedEdit(from: viewModel)

        viewModel.input.viewDidLoad()
        viewModel.input.productNameChanged("  焙茶  ")
        viewModel.input.priceTextChanged("350.5")
        viewModel.input.taxModeChanged(to: .includingTax)
        viewModel.input.payTypeSelected(at: 1)
        viewModel.input.saveTapped()

        XCTAssertEqual(
            edit()?.item,
            ShoppingItem(productName: "焙茶", price: 350.5, payType: "玉山", taxState: "含稅", photoURL: "photo-1")
        )
        XCTAssertNil(edit()?.newPhotoData)
    }

    func testSavingCarriesANewPhoto() {
        let viewModel = makeViewModel()
        let edit = capturedEdit(from: viewModel)
        let data = Data("new".utf8)

        viewModel.input.viewDidLoad()
        viewModel.input.photoSelected(data)
        viewModel.input.saveTapped()

        XCTAssertEqual(edit()?.newPhotoData, data)
    }

    /// 更正紀錄不是新的消費，改付款方式不能再扣一次回饋額度。
    func testChangingThePayTypeDoesNotTouchCards() {
        let viewModel = makeViewModel()

        viewModel.input.viewDidLoad()
        viewModel.input.payTypeSelected(at: 1)
        viewModel.input.saveTapped()

        XCTAssertEqual(cardRepository.saveCallCount, 0)
    }

    func testInvalidInputDisablesSave() {
        let viewModel = makeViewModel()
        var isEnabled: Bool?
        viewModel.output.isSaveEnabled.sink { isEnabled = $0 }.store(in: &cancellables)
        let edit = capturedEdit(from: viewModel)

        viewModel.input.viewDidLoad()
        XCTAssertEqual(isEnabled, true)

        viewModel.input.priceTextChanged("abc")
        XCTAssertEqual(isEnabled, false)
        viewModel.input.priceTextChanged("-1")
        XCTAssertEqual(isEnabled, false)
        viewModel.input.priceTextChanged("100")
        viewModel.input.productNameChanged("   ")
        XCTAssertEqual(isEnabled, false)

        viewModel.input.saveTapped()
        XCTAssertNil(edit())
    }

    func testCardLoadFailureStillOffersCash() {
        cardRepository.loadError = StubError.failure
        let viewModel = makeViewModel()
        var options: [String] = []
        var message: String?
        viewModel.output.payTypeOptions.sink { options = $0 }.store(in: &cancellables)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(options, ["現金"])
        XCTAssertEqual(message, "信用卡資料讀取失敗")
    }
}
