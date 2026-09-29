//
//  FeedbackPeriodTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

// MARK: - 週期邊界

final class FeedbackPeriodTests: XCTestCase {

    private static func calendar(_ timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }

    private let taipei = FeedbackPeriodTests.calendar("Asia/Taipei")

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, in calendar: Calendar? = nil) -> Date {
        (calendar ?? taipei).date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func interval(_ period: CapPeriod, closingDay: Int? = nil, at date: Date) -> DateInterval? {
        FeedbackPeriod.interval(containing: date, period: period, closingDay: closingDay, calendar: taipei)
    }

    func testCampaignHasNoInterval() {
        XCTAssertNil(interval(.campaign, at: date(2026, 9, 29)))
    }

    func testCalendarMonthRunsFromTheFirstToTheLastDay() {
        let month = interval(.calendarMonth, at: date(2026, 9, 30, 23))

        XCTAssertEqual(month?.start, date(2026, 9, 1, 0))
        XCTAssertEqual(month?.end, date(2026, 10, 1, 0))
    }

    func testQuartersStartInJanuaryAprilJulyAndOctober() {
        XCTAssertEqual(interval(.quarter, at: date(2026, 3, 31))?.start, date(2026, 1, 1, 0))
        XCTAssertEqual(interval(.quarter, at: date(2026, 4, 1))?.start, date(2026, 4, 1, 0))
        XCTAssertEqual(interval(.quarter, at: date(2026, 12, 31))?.end, date(2027, 1, 1, 0))
    }

    /// 結帳日 15 號：15 號當天屬於這一期，16 號起是下一期。
    func testTheClosingDayBelongsToTheCycleItCloses() {
        let onClosingDay = interval(.statementCycle, closingDay: 15, at: date(2026, 9, 15, 23))
        let dayAfter = interval(.statementCycle, closingDay: 15, at: date(2026, 9, 16, 0))

        XCTAssertEqual(onClosingDay?.start, date(2026, 8, 16, 0))
        XCTAssertEqual(onClosingDay?.end, date(2026, 9, 16, 0))
        XCTAssertEqual(dayAfter?.start, date(2026, 9, 16, 0))
        XCTAssertEqual(dayAfter?.end, date(2026, 10, 16, 0))
    }

    /// 結帳日 31 號遇到只有 30 或 28 天的月份，以當月最後一天結帳。
    func testAClosingDayPastTheMonthEndUsesTheLastDay() {
        let february = interval(.statementCycle, closingDay: 31, at: date(2026, 2, 20))
        let march = interval(.statementCycle, closingDay: 31, at: date(2026, 3, 1))

        XCTAssertEqual(february?.start, date(2026, 2, 1, 0), "1/31 結帳，2/1 起算")
        XCTAssertEqual(february?.end, date(2026, 3, 1, 0), "2/28 結帳")
        XCTAssertEqual(march?.start, date(2026, 3, 1, 0))
        XCTAssertEqual(march?.end, date(2026, 4, 1, 0))
    }

    func testClosingDay29InALeapYear() {
        let february = interval(.statementCycle, closingDay: 29, at: date(2028, 2, 29))

        XCTAssertEqual(february?.start, date(2028, 1, 30, 0))
        XCTAssertEqual(february?.end, date(2028, 3, 1, 0))
    }

    func testAStatementCycleCrossesTheYear() {
        let cycle = interval(.statementCycle, closingDay: 5, at: date(2026, 12, 25))

        XCTAssertEqual(cycle?.start, date(2026, 12, 6, 0))
        XCTAssertEqual(cycle?.end, date(2027, 1, 6, 0))
    }

    func testAStatementCycleWithoutAClosingDayIsNotSplit() {
        XCTAssertNil(interval(.statementCycle, closingDay: nil, at: date(2026, 9, 29)))
    }

    /// 台北 10/1 00:30 在東京已經是 10/1 01:30、在 UTC 還是 9/30；週期跟著傳入的時區切。
    func testTheMonthFollowsTheCalendarsTimeZone() {
        let instant = date(2026, 10, 1, 0)
        let utc = Self.calendar("UTC")

        XCTAssertEqual(interval(.calendarMonth, at: instant.addingTimeInterval(1800))?.start, date(2026, 10, 1, 0))
        XCTAssertEqual(
            FeedbackPeriod.interval(containing: instant, period: .calendarMonth, closingDay: nil, calendar: utc)?.start,
            date(2026, 9, 1, 0, in: utc)
        )
    }
}

// MARK: - 依週期計算剩餘

final class PeriodRemainingTests: XCTestCase {

    private let planID = UUID()
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return calendar
    }

    private func date(_ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: h))!
    }

    private func entry(base: Double = 0, bonus: Double = 0, on date: Date) -> FeedbackEntry {
        FeedbackEntry(
            id: UUID(), cardID: UUID(), date: date, amount: base + bonus, shoppingItemID: nil,
            planID: planID, baseAmount: base, bonusAmount: bonus
        )
    }

    private func plan(bonusPeriod: CapPeriod?, basePeriod: CapPeriod? = nil) -> CardPlan {
        CardPlan(
            id: planID, name: "", baseRate: 2.5, baseCap: 1000,
            bonus: CardPlan.Bonus(rate: 6, cap: 500, label: "", capPeriod: bonusPeriod),
            note: "", baseCapPeriod: basePeriod
        )
    }

    /// 上個月用掉的加碼不影響這個月。
    func testAMonthlyCapOnlyCountsThisMonth() {
        let entries = [entry(bonus: 400, on: date(8, 31, 23)), entry(bonus: 120, on: date(9, 1, 0))]

        let remaining = FeedbackCalculator.remainingBonus(
            of: plan(bonusPeriod: .calendarMonth), in: entries, at: date(9, 29), calendar: calendar
        )

        XCTAssertEqual(remaining, 380)
    }

    func testACampaignCapCountsEverything() {
        let entries = [entry(bonus: 400, on: date(8, 31)), entry(bonus: 90, on: date(9, 1))]

        XCTAssertEqual(
            FeedbackCalculator.remainingBonus(of: plan(bonusPeriod: nil), in: entries, at: date(9, 29), calendar: calendar),
            10
        )
    }

    func testAStatementCapUsesTheCardsClosingDay() {
        let entries = [entry(bonus: 300, on: date(9, 15, 22)), entry(bonus: 50, on: date(9, 16, 9))]

        let remaining = FeedbackCalculator.remainingBonus(
            of: plan(bonusPeriod: .statementCycle), in: entries, closingDay: 15, at: date(9, 29), calendar: calendar
        )

        XCTAssertEqual(remaining, 450)
    }

    /// 基本與加碼可以各有各的週期。
    func testBaseAndBonusPeriodsAreIndependent() {
        let entries = [entry(base: 600, bonus: 300, on: date(7, 20))]
        let plan = plan(bonusPeriod: .calendarMonth, basePeriod: .quarter)

        XCTAssertEqual(FeedbackCalculator.remainingBase(of: plan, in: entries, at: date(9, 29), calendar: calendar), 400)
        XCTAssertEqual(FeedbackCalculator.remainingBonus(of: plan, in: entries, at: date(9, 29), calendar: calendar), 500)
    }

    /// 這個月的加碼額度用完時，這筆只拿得到基本回饋；下個月又能拿加碼。
    func testTheQuoteUsesThePeriodOfThePurchase() {
        let entries = [entry(bonus: 500, on: date(9, 10))]
        let plan = plan(bonusPeriod: .calendarMonth)

        let september = FeedbackCalculator.quote(
            plan: plan, price: 1000, qualifiesForBonus: true, entries: entries, at: date(9, 29), calendar: calendar
        )
        let october = FeedbackCalculator.quote(
            plan: plan, price: 1000, qualifiesForBonus: true, entries: entries, at: date(10, 1), calendar: calendar
        )

        XCTAssertEqual(september.bonus, 0)
        XCTAssertEqual(october.bonus, 60)
    }
}
