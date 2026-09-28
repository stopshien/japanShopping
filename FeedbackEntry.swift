//
//  FeedbackEntry.swift
//  japanShopping
//

import Foundation

/// 回饋明細的一筆：某張卡因為某筆消費拿到多少回饋。
///
/// 卡片的剩餘額度不再存成一個持續往下扣的數字，而是由明細加總算出，
/// 這樣刪除消費時只要移除對應的明細，額度就會自動回來。
struct FeedbackEntry: Codable, Equatable {
    var id: UUID
    var cardID: UUID
    var date: Date
    /// 計入卡片回饋上限的金額，已取到分位。
    var amount: Double
    /// 對應的消費。遷移前累積的已用額度沒有對應的消費，所以是 nil。
    var shoppingItemID: UUID?
}

extension Card {

    /// 剩餘回饋 = 上限 − 這張卡所有明細的加總，最低為 0。
    /// 遷移前沒有 id 的卡片還沒有明細，只能沿用舊的剩餘額度。
    func remainingFeedback(in entries: [FeedbackEntry]) -> Double {
        guard let id else { return feedbackRemaining }
        let used = entries.filter { $0.cardID == id }.reduce(0) { $0 + $1.amount }
        return (max(0, limit - used) * 100).rounded() / 100
    }
}
