//
//  FeedbackPeriod.swift
//  japanShopping
//

import Foundation

/// 回饋上限多久重新計算一次。
enum CapPeriod: String, Codable, CaseIterable {
    /// 不重置：整個活動期間共用一個上限。沒有設定週期的上限（包含舊資料）都是這種。
    case campaign
    /// 每個日曆月，1 號到月底。
    case calendarMonth
    /// 每期帳單，從上期結帳日隔天到本期結帳日。需要卡片的結帳日。
    case statementCycle
    /// 每季：1–3、4–6、7–9、10–12 月。
    case quarter
}

/// 找出某個日期所在的上限週期。全部是純函式，時區與曆法由傳入的 `Calendar` 決定。
///
/// 銀行多半以請款入帳日認定期別，App 只知道刷卡日，所以週期邊界附近的消費只能估算。
enum FeedbackPeriod {

    /// `date` 所在的週期；`campaign` 或缺少結帳日時為 nil，代表不分週期、全部都算。
    static func interval(
        containing date: Date,
        period: CapPeriod,
        closingDay: Int?,
        calendar: Calendar
    ) -> DateInterval? {
        switch period {
        case .campaign:
            return nil
        case .calendarMonth:
            return calendar.dateInterval(of: .month, for: date)
        case .quarter:
            return quarter(containing: date, calendar: calendar)
        case .statementCycle:
            guard let closingDay else { return nil }
            return statementCycle(containing: date, closingDay: closingDay, calendar: calendar)
        }
    }

    /// 季的起點是 1、4、7、10 月的 1 號。
    private static func quarter(containing date: Date, calendar: Calendar) -> DateInterval? {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else { return nil }
        let firstMonth = (month - 1) / 3 * 3 + 1
        guard let start = calendar.date(from: DateComponents(year: year, month: firstMonth, day: 1)),
              let end = calendar.date(byAdding: .month, value: 3, to: start) else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// 結帳日當天屬於這一期，隔天開始下一期。
    /// 結帳日超過當月天數時（例如 31 號遇到 2 月）以當月最後一天結帳。
    private static func statementCycle(containing date: Date, closingDay: Int, calendar: Calendar) -> DateInterval? {
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start,
              let thisClose = dayAfterClosing(inMonthOf: monthStart, closingDay: closingDay, calendar: calendar)
        else { return nil }

        let offsets = date < thisClose ? (-1, 0) : (0, 1)
        guard let startMonth = calendar.date(byAdding: .month, value: offsets.0, to: monthStart),
              let endMonth = calendar.date(byAdding: .month, value: offsets.1, to: monthStart),
              let start = dayAfterClosing(inMonthOf: startMonth, closingDay: closingDay, calendar: calendar),
              let end = dayAfterClosing(inMonthOf: endMonth, closingDay: closingDay, calendar: calendar)
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// 那個月結帳日的隔天 0 點，也就是下一期的起點。
    private static func dayAfterClosing(inMonthOf monthStart: Date, closingDay: Int, calendar: Calendar) -> Date? {
        guard let days = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
        let day = min(max(1, closingDay), days.count)
        guard let closing = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { return nil }
        return calendar.date(byAdding: .day, value: 1, to: closing)
    }
}

extension CapPeriod {

    /// 表單上的選項文字。
    var title: String {
        switch self {
        case .campaign: return "不重置"
        case .calendarMonth: return "每月"
        case .statementCycle: return "每期帳單"
        case .quarter: return "每季"
        }
    }

    /// 放在上限前面，例如「每月上限 500」；不重置時不加字。
    var capPrefix: String {
        switch self {
        case .campaign: return ""
        case .calendarMonth: return "每月"
        case .statementCycle: return "每期"
        case .quarter: return "每季"
        }
    }

    /// 放在剩餘前面，例如「本月剩餘」；不重置時不加字。
    var currentPrefix: String {
        switch self {
        case .campaign: return ""
        case .calendarMonth: return "本月"
        case .statementCycle: return "本期"
        case .quarter: return "本季"
        }
    }
}
