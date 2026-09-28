//
//  ShoppingItem.swift
//  japanShopping
//
//  原本名為 List，遷移時改為更明確的名稱。
//  屬性名稱不可更動：存檔是 property list，欄位名就是既有使用者資料的鍵。
//

import Foundation

struct ShoppingItem: Codable, Equatable {
    var productName: String
    var price: Double
    var payType: String
    var taxState: String
    var photoURL: String?
    /// 加入消費紀錄的時間。這個欄位出現前存下的紀錄沒有日期，所以是 optional，
    /// 舊存檔缺少這個鍵仍能讀取。
    var purchasedAt: Date?
    /// 穩定的識別碼，之後的回饋明細以它對應消費。舊紀錄由 `IdentityMigration` 補上。
    var id: UUID?
}
