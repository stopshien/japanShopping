//
//  ShoppingListStubs.swift
//  japanShoppingTests
//

import Foundation
@testable import japanShopping

final class ShoppingListRepositoryStub: ShoppingListRepository {

    var storedItems: [ShoppingItem]
    var loadError: Error?
    var saveError: Error?
    private(set) var saveCallCount = 0

    init(storedItems: [ShoppingItem] = []) {
        self.storedItems = storedItems
    }

    func load() throws -> [ShoppingItem] {
        if let loadError { throw loadError }
        return storedItems
    }

    func save(_ items: [ShoppingItem]) throws {
        saveCallCount += 1
        if let saveError { throw saveError }
        storedItems = items
    }
}

final class ImageStoreStub: ImageStore {

    var storedImages: [String: Data]
    private(set) var removedNames: [String] = []

    init(storedImages: [String: Data] = [:]) {
        self.storedImages = storedImages
    }

    func save(_ data: Data) throws -> String {
        let name = UUID().uuidString
        storedImages[name] = data
        return name
    }

    func loadData(named filename: String) throws -> Data {
        guard let data = storedImages[filename] else { throw StubError.failure }
        return data
    }

    func remove(named filename: String) throws {
        removedNames.append(filename)
        storedImages[filename] = nil
    }
}
