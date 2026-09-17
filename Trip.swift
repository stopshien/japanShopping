//
//  Trip.swift
//  japanShopping
//

import Foundation

/// 一次旅行。幣別屬於旅行而非使用者 —— 這趟日本、下趟韓國。
/// 購物清單依專案分開存放；信用卡則是跨專案共用的實體卡片。
struct Trip: Codable, Equatable, Identifiable {

    let id: UUID
    var name: String
    var currency: Currency
    let createdAt: Date

    init(id: UUID = UUID(), name: String, currency: Currency, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.currency = currency
        self.createdAt = createdAt
    }

    /// 建立專案時預先填入的名稱，例如「日幣 9/17」。
    static func defaultName(for currency: Currency, on date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "M/d"
        return "\(currency.title) \(formatter.string(from: date))"
    }
}
