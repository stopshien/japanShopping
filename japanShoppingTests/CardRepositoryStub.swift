//
//  CardRepositoryStub.swift
//  japanShoppingTests
//

import Foundation
@testable import japanShopping

/// 測試用的 CardRepository，不碰檔案系統。
final class CardRepositoryStub: CardRepository {

    var storedCards: [Card]
    var loadError: Error?
    var saveError: Error?
    private(set) var saveCallCount = 0

    init(storedCards: [Card] = []) {
        self.storedCards = storedCards
    }

    func load() throws -> [Card] {
        if let loadError { throw loadError }
        return storedCards
    }

    func save(_ cards: [Card]) throws {
        saveCallCount += 1
        if let saveError { throw saveError }
        storedCards = cards
    }
}

enum StubError: Error {
    case failure
}
