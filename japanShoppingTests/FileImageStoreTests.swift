//
//  FileImageStoreTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

final class FileImageStoreTests: XCTestCase {

    private var directory: URL!
    private var store: FileImageStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = FileImageStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        store = nil
        directory = nil
        try super.tearDownWithError()
    }

    func testSaveReturnsAFilenameThatCanBeLoadedBack() throws {
        let data = Data("image".utf8)

        let filename = try store.save(data)

        XCTAssertEqual(try store.loadData(named: filename), data)
    }

    /// 只保存檔名，不保存絕對路徑：App 容器路徑每次安裝都會變。
    func testSavedNameIsNotAPath() throws {
        let filename = try store.save(Data("image".utf8))

        XCTAssertFalse(filename.contains("/"))
        XCTAssertFalse(filename.hasSuffix(".jpg"))
    }

    func testSaveWritesAJPEGFile() throws {
        let filename = try store.save(Data("image".utf8))

        let expected = directory.appendingPathComponent(filename).appendingPathExtension("jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }

    func testRemoveDeletesTheFile() throws {
        let filename = try store.save(Data("image".utf8))

        try store.remove(named: filename)

        XCTAssertThrowsError(try store.loadData(named: filename))
    }

    func testRemovingAMissingFileDoesNotThrow() throws {
        XCTAssertNoThrow(try store.remove(named: "does-not-exist"))
    }
}
