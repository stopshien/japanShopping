//
//  TripRepository.swift
//  japanShopping
//

import Foundation

protocol TripRepository {
    func load() throws -> [Trip]
    func save(_ trips: [Trip]) throws
    func loadCurrentTripID() -> UUID?
    func saveCurrentTripID(_ id: UUID?)
}

/// 專案清單存成 Documents 下的 "trips"，目前選中的專案存在 UserDefaults。
/// 清單是會成長的集合所以用檔案；「選中哪一個」是單一設定值。
final class FileTripRepository: TripRepository {

    private enum Constants {
        static let fileName = "trips"
        static let currentTripKey = "currentTripID"
    }

    private let fileURL: URL
    private let defaults: UserDefaults

    init(
        fileURL: URL = DocumentsDirectory.fileURL(named: Constants.fileName),
        defaults: UserDefaults = .standard
    ) {
        self.fileURL = fileURL
        self.defaults = defaults
    }

    func load() throws -> [Trip] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try PropertyListDecoder().decode([Trip].self, from: data)
    }

    func save(_ trips: [Trip]) throws {
        let data = try PropertyListEncoder().encode(trips)
        try data.write(to: fileURL)
    }

    func loadCurrentTripID() -> UUID? {
        guard let value = defaults.string(forKey: Constants.currentTripKey) else { return nil }
        return UUID(uuidString: value)
    }

    func saveCurrentTripID(_ id: UUID?) {
        guard let id else {
            defaults.removeObject(forKey: Constants.currentTripKey)
            return
        }
        defaults.set(id.uuidString, forKey: Constants.currentTripKey)
    }
}
