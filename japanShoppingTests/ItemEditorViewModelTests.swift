//
//  ItemEditorViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

final class ItemEditorViewModelTests: XCTestCase {

    private var cancellables: Set<AnyCancellable>!

    private let item = ShoppingItem(
        productName: "抹茶", price: 200, payType: "玉山", taxState: "未稅", photoURL: "photo-1"
    )

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    private func makeViewModel(photoData: Data? = nil) -> ItemEditorViewModel {
        ItemEditorViewModel(item: item, photoData: photoData)
    }

    private func capturedEdit(from viewModel: ItemEditorViewModel) -> () -> ItemEdit? {
        var edit: ItemEdit?
        viewModel.output.didSave.sink { edit = $0 }.store(in: &cancellables)
        return { edit }
    }

    // MARK: - 顯示

    func testShowsTheCurrentValues() {
        let viewModel = makeViewModel()
        var name: String?
        var price: String?
        var payType: String?
        viewModel.output.productName.sink { name = $0 }.store(in: &cancellables)
        viewModel.output.priceDescription.sink { price = $0 }.store(in: &cancellables)
        viewModel.output.payTypeDescription.sink { payType = $0 }.store(in: &cancellables)

        XCTAssertEqual(name, "抹茶")
        XCTAssertEqual(price, "200$（未稅）")
        XCTAssertEqual(payType, "玉山")
    }

    // MARK: - 儲存

    /// 價格、稅別與付款方式在加入紀錄時已用來計算信用卡回饋，編輯後必須原封不動。
    func testSavingOnlyChangesTheNameAndKeepsTheLockedFields() {
        let viewModel = makeViewModel()
        let edit = capturedEdit(from: viewModel)

        viewModel.input.productNameChanged("  焙茶  ")
        viewModel.input.saveTapped()

        XCTAssertEqual(
            edit()?.item,
            ShoppingItem(productName: "焙茶", price: 200, payType: "玉山", taxState: "未稅", photoURL: "photo-1")
        )
        XCTAssertNil(edit()?.newPhotoData)
    }

    func testSavingCarriesANewPhoto() {
        let viewModel = makeViewModel()
        let edit = capturedEdit(from: viewModel)
        let data = Data("new".utf8)

        viewModel.input.photoSelected(data)
        viewModel.input.saveTapped()

        XCTAssertEqual(edit()?.newPhotoData, data)
    }

    func testEmptyNameDisablesSave() {
        let viewModel = makeViewModel()
        var isEnabled: Bool?
        viewModel.output.isSaveEnabled.sink { isEnabled = $0 }.store(in: &cancellables)
        let edit = capturedEdit(from: viewModel)

        XCTAssertEqual(isEnabled, true)

        viewModel.input.productNameChanged("   ")
        XCTAssertEqual(isEnabled, false)

        viewModel.input.saveTapped()
        XCTAssertNil(edit())
    }
}
