//
//  TripMigration.swift
//  japanShopping
//

import Foundation

/// 把「單一購物清單」的舊資料轉成第一個專案。
///
/// 舊版把清單存在 Documents/"list"，幣別存在 UserProfile 裡。
/// 引入專案後兩者都屬於專案，這裡負責一次性搬移，避免既有清單消失。
enum TripMigration {

    private enum Constants {
        static let legacyListFileName = "list"
        static let legacyProfileKey = "userProfile"
    }

    /// 舊版 UserProfile 的形狀，只為了取出幣別。
    private struct LegacyProfile: Decodable {
        let currency: Currency?
    }

    static func run(tripRepository: TripRepository, defaults: UserDefaults = .standard) {
        // 已經有專案就代表遷移過了。
        guard let trips = try? tripRepository.load(), trips.isEmpty else { return }

        let legacyURL = DocumentsDirectory.fileURL(named: Constants.legacyListFileName)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }

        let currency = legacyCurrency(from: defaults) ?? .japaneseYen
        let trip = Trip(name: Trip.defaultName(for: currency), currency: currency)

        let newURL = DocumentsDirectory.fileURL(named: FileTripContentStore.fileName(for: trip.id))
        do {
            try FileManager.default.moveItem(at: legacyURL, to: newURL)
            try tripRepository.save([trip])
            tripRepository.saveCurrentTripID(trip.id)
        } catch {
            // 搬移失敗就維持原狀，下次啟動再試；不會弄丟舊檔。
        }
    }

    private static func legacyCurrency(from defaults: UserDefaults) -> Currency? {
        guard let data = defaults.data(forKey: Constants.legacyProfileKey) else { return nil }
        return try? JSONDecoder().decode(LegacyProfile.self, from: data).currency
    }
}
