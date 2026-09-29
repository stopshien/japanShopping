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
        /// 加碼上限多久重新計算；nil 為不重置。
        var capPeriod: CapPeriod? = nil
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
    /// 基本回饋上限多久重新計算；nil 為不重置（舊資料都是這種）。
    var baseCapPeriod: CapPeriod? = nil
    /// 回饋開始日（含），當天 0 點；nil 為沒有限制。
    var validFrom: Date? = nil
    /// 回饋結束日（含），當天 0 點；nil 為沒有期限。
    var validUntil: Date? = nil
    /// 使用者已看過這個方案的到期提示，之後不再提示。改了結束日就會清掉。
    var expiryAcknowledged: Bool? = nil
}

extension CardPlan {

    /// `date` 那天是否在回饋期間內。起迄日都以天計算，兩端都包含。
    func isActive(on date: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        if let validFrom, day < calendar.startOfDay(for: validFrom) { return false }
        if let validUntil, day > calendar.startOfDay(for: validUntil) { return false }
        return true
    }

    /// 結束日已經過了。
    func isExpired(on date: Date, calendar: Calendar) -> Bool {
        guard let validUntil else { return false }
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: validUntil)
    }

    /// 距離結束日還有幾天；當天到期為 0，沒有期限或已過期時為 nil。
    func daysUntilExpiry(from date: Date, calendar: Calendar) -> Int? {
        guard let validUntil, !isExpired(on: date, calendar: calendar) else { return nil }
        return calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: validUntil)
        ).day
    }
}
