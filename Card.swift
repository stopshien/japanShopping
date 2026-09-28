//
//  Card.swift
//  japanShopping
//

import Foundation

/// 信用卡資料。純資料型別，存取邏輯由 CardRepository 負責。
struct Card: Codable, Equatable {
    let name: String
    let percent: Double
    let limit: Double
    var feedbackMoney = 0.0
    var feedbackRemaining = 0.0
    /// 穩定的識別碼，之後的回饋明細以它對應卡片；名稱可以改，不能當識別。
    /// 這個欄位出現前存下的卡片沒有 id，由 `IdentityMigration` 補上。
    var id: UUID?
}
