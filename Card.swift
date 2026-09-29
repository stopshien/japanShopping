//
//  Card.swift
//  japanShopping
//

import Foundation

/// 信用卡資料。純資料型別，存取邏輯由 CardRepository 負責。
///
/// 回饋的趴數與上限在 `plans` 裡。`percent`、`limit`、`feedbackMoney`、`feedbackRemaining`
/// 是舊版欄位，只為了讀得回舊存檔而保留；新卡仍會寫入，但計算不再讀它們。
struct Card: Codable, Equatable {
    let name: String
    let percent: Double
    let limit: Double
    var feedbackMoney = 0.0
    var feedbackRemaining = 0.0
    /// 穩定的識別碼，之後的回饋明細以它對應卡片；名稱可以改，不能當識別。
    /// 這個欄位出現前存下的卡片沒有 id，由 `IdentityMigration` 補上。
    var id: UUID?
    /// 回饋方案，至少一個。nil 只出現在尚未轉換的舊檔，由 `CardPlanMigration` 補上。
    var plans: [CardPlan]?
    /// 帳單結帳日（每月幾號），上限以「每期帳單」計算時需要。同一張卡的方案共用一份帳單。
    var statementClosingDay: Int? = nil
}
