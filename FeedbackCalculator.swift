//
//  FeedbackCalculator.swift
//  japanShopping
//

import Foundation

/// 一筆刷卡能拿到的回饋。金額都是毛額，手續費另外列出。
struct FeedbackQuote: Equatable {
    let base: Double
    let bonus: Double
    let fee: Double

    var total: Double { FeedbackCalculator.roundedToCents(base + bonus) }
}

/// 回饋與剩餘額度的計算，全部是純函式，方便測試。
///
/// 回饋以毛額計算（趴數 × 金額），和銀行計算上限的方式一致；
/// 海外交易手續費另外算，只用來顯示。
enum FeedbackCalculator {

    /// 海外交易手續費的趴數。之後可能改成每張卡各自設定（規劃第 6 階段）。
    static let foreignFeePercent = 1.5

    /// 這個方案還剩多少基本回饋額度；nil 代表無上限。
    static func remainingBase(of plan: CardPlan, in entries: [FeedbackEntry]) -> Double? {
        guard let cap = plan.baseCap else { return nil }
        let used = entries.filter { $0.planID == plan.id }.reduce(0) { $0 + $1.countedBase }
        return roundedToCents(max(0, cap - used))
    }

    /// 這個方案還剩多少加碼額度；沒有加碼或加碼無上限時為 nil。
    static func remainingBonus(of plan: CardPlan, in entries: [FeedbackEntry]) -> Double? {
        guard let cap = plan.bonus?.cap else { return nil }
        let used = entries.filter { $0.planID == plan.id }.reduce(0) { $0 + $1.countedBonus }
        return roundedToCents(max(0, cap - used))
    }

    /// 這筆消費的回饋。每一層最多只到剩餘額度：額度用完，銀行也不會再給。
    /// 加碼只有在使用者勾選「符合加碼」時才算。
    static func quote(
        plan: CardPlan,
        price: Double,
        qualifiesForBonus: Bool,
        entries: [FeedbackEntry]
    ) -> FeedbackQuote {
        var base = roundedToCents(plan.baseRate * price * 0.01)
        if let remaining = remainingBase(of: plan, in: entries) {
            base = min(base, remaining)
        }

        var bonus = 0.0
        if qualifiesForBonus, let planBonus = plan.bonus {
            bonus = roundedToCents(planBonus.rate * price * 0.01)
            if let remaining = remainingBonus(of: plan, in: entries) {
                bonus = min(bonus, remaining)
            }
        }

        let fee = roundedToCents(foreignFeePercent * price * 0.01)
        return FeedbackQuote(base: max(0, base), bonus: max(0, bonus), fee: fee)
    }

    /// 回饋金額是浮點相乘相減的結果，不取到分位就會存進
    /// 999.3629999999999 這種值，並在每次消費後持續累積誤差。
    static func roundedToCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
