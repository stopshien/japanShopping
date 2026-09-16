//
//  FileShoppingListRepositoryTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

final class FileShoppingListRepositoryTests: XCTestCase {

    private var fileURL: URL!
    private var repository: FileShoppingListRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("list")
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        repository = FileShoppingListRepository(fileURL: fileURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        repository = nil
        fileURL = nil
        try super.tearDownWithError()
    }

    func testLoadReturnsEmptyArrayWhenFileDoesNotExist() throws {
        XCTAssertEqual(try repository.load(), [])
    }

    func testSaveThenLoadReturnsTheSameItems() throws {
        let items = [
            ShoppingItem(productName: "抹茶", price: 100, payType: "現金", taxState: "含稅", photoURL: "abc"),
            ShoppingItem(productName: "咖啡", price: 250, payType: "信用卡", taxState: "未稅")
        ]

        try repository.save(items)

        XCTAssertEqual(try repository.load(), items)
    }

    /// 遷移前是 List.saveList 用 PropertyListEncoder 寫入 Documents 下的 "list"。
    /// 型別雖然改名為 ShoppingItem，欄位名不變，所以舊存檔仍須讀得回來。
    func testLoadReadsFileWrittenByTheLegacyFormat() throws {
        let legacyItems = [ShoppingItem(productName: "舊項目", price: 88, payType: "現金", taxState: "含稅", photoURL: nil)]
        let data = try PropertyListEncoder().encode(legacyItems)
        try data.write(to: fileURL)

        XCTAssertEqual(try repository.load(), legacyItems)
    }
}
