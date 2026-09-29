//
//  CardPlan.swift
//  japanShopping
//

import Foundation

/// 信用卡的一個回饋方案。
///
/// 多數卡只有一個方案；像台新 Richart 這種每天可以切換權益的卡，每種權益是一個方案，
/// 刷卡時由使用者選當天用的是哪一個。
struct CardPlan: Codable, Equatable {

    /// 加碼回饋。通常有上限，也常有 App 無法判斷的條件（指定店家、登錄），
    /// 所以刷卡時由使用者勾選這筆是否符合。
    struct Bonus: Codable, Equatable {
        var rate: Double
        /// 加碼回饋的上限金額（毛額）；nil 為無上限。
        var cap: Double?
        /// 「符合加碼」開關旁的說明，例如「指定店家」。
        var label: String
    }

    var id: UUID
    /// 只有一個方案的卡片不顯示方案名稱，可以是空字串。
    var name: String
    /// 基本回饋趴數，每筆刷卡都有。
    var baseRate: Double
    /// 基本回饋的上限金額（毛額）；nil 為無上限。舊卡轉換過來的上限放在這裡。
    var baseCap: Double?
    var bonus: Bonus?
    /// App 無法判斷的條件，只給使用者看。
    var note: String
}
