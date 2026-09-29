//
//  FeedbackEntry.swift
//  japanShopping
//

import Foundation

/// 回饋明細的一筆：某張卡的某個方案因為某筆消費拿到多少回饋。
///
/// 卡片的剩餘額度不再存成一個持續往下扣的數字，而是由明細加總算出，
/// 這樣刪除消費時只要移除對應的明細，額度就會自動回來。
struct FeedbackEntry: Codable, Equatable {
    var id: UUID
    var cardID: UUID
    var date: Date
    /// 這筆回饋的總額，已取到分位。
    var amount: Double
    /// 對應的消費。遷移前累積的已用額度沒有對應的消費，所以是 nil。
    var shoppingItemID: UUID?
    /// 所屬方案。方案出現前的明細由 `CardPlanMigration` 補上。
    var planID: UUID?
    /// 基本回饋（毛額）。方案出現前的明細沒有這個欄位，整筆 `amount` 都算基本回饋。
    var baseAmount: Double?
    /// 加碼回饋（毛額）。方案出現前的明細沒有加碼。
    var bonusAmount: Double?

    /// 計入基本回饋上限的金額。
    var countedBase: Double { baseAmount ?? amount }
    /// 計入加碼上限的金額。
    var countedBonus: Double { bonusAmount ?? 0 }
}
