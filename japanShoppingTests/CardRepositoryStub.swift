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

/// 測試用的 FeedbackLedgerRepository，不碰檔案系統。
final class FeedbackLedgerRepositoryStub: FeedbackLedgerRepository {

    var storedEntries: [FeedbackEntry]
    var loadError: Error?
    var saveError: Error?
    private(set) var saveCallCount = 0

    init(storedEntries: [FeedbackEntry] = []) {
        self.storedEntries = storedEntries
    }

    func load() throws -> [FeedbackEntry] {
        if let loadError { throw loadError }
        return storedEntries
    }

    func save(_ entries: [FeedbackEntry]) throws {
        saveCallCount += 1
        if let saveError { throw saveError }
        storedEntries = entries
    }
}
