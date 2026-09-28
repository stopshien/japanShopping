//
//  IdentityMigration.swift
//  japanShopping
//

import Foundation

/// 替加入識別碼之前存下的卡片與消費紀錄補上 `id`。
///
/// 每次啟動都會檢查，但只有真的缺 id 時才寫檔，所以已遷移過的資料不會被重寫。
/// 補上的 id 一旦存檔就固定，之後的回饋明細會用它對應卡片與消費。
enum IdentityMigration {

    static func run(
        cardRepository: CardRepository,
        tripRepository: TripRepository,
        tripContentStore: TripContentStore
    ) {
        if let cards = try? cardRepository.load(), let migrated = assigningIDs(to: cards, id: \.id) {
            try? cardRepository.save(migrated)
        }

        let trips = (try? tripRepository.load()) ?? []
        for trip in trips {
            let repository = tripContentStore.shoppingListRepository(for: trip.id)
            if let items = try? repository.load(), let migrated = assigningIDs(to: items, id: \.id) {
                try? repository.save(migrated)
            }
        }
    }

    /// 沒有任何一筆缺 id 時回傳 nil，呼叫端就不必寫檔。
    static func assigningIDs<Value>(to values: [Value], id: WritableKeyPath<Value, UUID?>) -> [Value]? {
        guard values.contains(where: { $0[keyPath: id] == nil }) else { return nil }
        return values.map { value in
            var value = value
            if value[keyPath: id] == nil {
                value[keyPath: id] = UUID()
            }
            return value
        }
    }
}
