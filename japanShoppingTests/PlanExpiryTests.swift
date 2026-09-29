//
//  PlanExpiryTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

private let taipei: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
    return calendar
}()

private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
    taipei.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}

private func plan(from: Date? = nil, until: Date? = nil, acknowledged: Bool? = nil, name: String = "") -> CardPlan {
    CardPlan(
        id: UUID(), name: name, baseRate: 3, baseCap: nil, bonus: nil, note: "",
        validFrom: from, validUntil: until, expiryAcknowledged: acknowledged
    )
}

// MARK: - 回饋期間

final class PlanValidityTests: XCTestCase {

    /// 起迄日都包含：結束日當天還能用，隔天才算過期。
    func testBothEndsAreInclusive() {
        let plan = plan(from: day(2026, 7, 1), until: day(2026, 12, 31))

        XCTAssertFalse(plan.isActive(on: day(2026, 6, 30, 23), calendar: taipei))
        XCTAssertTrue(plan.isActive(on: day(2026, 7, 1), calendar: taipei))
        XCTAssertTrue(plan.isActive(on: day(2026, 12, 31, 23), calendar: taipei))
        XCTAssertFalse(plan.isActive(on: day(2027, 1, 1), calendar: taipei))
        XCTAssertFalse(plan.isExpired(on: day(2026, 12, 31, 23), calendar: taipei))
        XCTAssertTrue(plan.isExpired(on: day(2027, 1, 1), calendar: taipei))
    }

    func testAPlanWithoutDatesIsAlwaysActive() {
        XCTAssertTrue(plan().isActive(on: day(2030, 1, 1), calendar: taipei))
        XCTAssertFalse(plan().isExpired(on: day(2030, 1, 1), calendar: taipei))
    }

    /// 還沒開始的方案不算過期，只是不在期間內。
    func testAPlanThatHasNotStartedIsNotExpired() {
        let plan = plan(from: day(2027, 1, 1))

        XCTAssertFalse(plan.isActive(on: day(2026, 12, 31), calendar: taipei))
        XCTAssertFalse(plan.isExpired(on: day(2026, 12, 31), calendar: taipei))
    }

    func testDaysUntilExpiry() {
        let plan = plan(until: day(2026, 10, 13))

        XCTAssertEqual(plan.daysUntilExpiry(from: day(2026, 9, 29, 20), calendar: taipei), 14)
        XCTAssertEqual(plan.daysUntilExpiry(from: day(2026, 10, 13, 23), calendar: taipei), 0)
        XCTAssertNil(plan.daysUntilExpiry(from: day(2026, 10, 14), calendar: taipei))
    }
}

// MARK: - 到期提示

final class PlanExpiryViewModelTests: XCTestCase {

    private var repository: CardRepositoryStub!
    private let now = day(2027, 1, 2, 9)

    override func setUp() {
        super.setUp()
        repository = CardRepositoryStub()
    }

    override func tearDown() {
        repository = nil
        super.tearDown()
    }

    private func makeViewModel() -> PlanExpiryViewModel {
        PlanExpiryViewModel(repository: repository, now: { self.now }, calendar: taipei)
    }

    private func card(_ name: String, plans: [CardPlan], closingDay: Int? = nil) -> Card {
        Card(name: name, percent: 3, limit: 0, feedbackRemaining: 0, id: UUID(), plans: plans,
             statementClosingDay: closingDay)
    }

    func testNothingToSayWhenNoPlanHasExpired() {
        repository.storedCards = [card("玉山", plans: [plan(until: day(2027, 6, 30))]), card("台新", plans: [plan()])]

        XCTAssertNil(makeViewModel().check())
    }

    func testExpiredPlansAreListedByCardAndPlan() {
        repository.storedCards = [
            card("熊本熊", plans: [plan(until: day(2026, 12, 31))]),
            card("Richart", plans: [plan(until: day(2026, 12, 20), name: "玩旅刷"), plan(name: "假日刷")])
        ]

        let notice = makeViewModel().check()

        XCTAssertEqual(notice?.title, "回饋方案已到期")
        XCTAssertEqual(notice?.message, "以下方案已不會出現在刷卡選單：\n・熊本熊（到 2026/12/31）\n・Richart・玩旅刷（到 2026/12/20）")
        XCTAssertEqual(notice?.renewTitle, "為「熊本熊」設定新一期")
    }

    /// 每個方案只提示一次。
    func testAcknowledgedPlansAreNotListedAgain() {
        repository.storedCards = [card("熊本熊", plans: [plan(until: day(2026, 12, 31))])]
        let viewModel = makeViewModel()

        _ = viewModel.check()
        viewModel.acknowledge()

        XCTAssertEqual(repository.storedCards[0].plans?[0].expiryAcknowledged, true)
        XCTAssertNil(makeViewModel().check())
    }

    /// 「設定新一期」只處理第一張卡，其他卡下次再提示。
    func testRenewingAcknowledgesOnlyTheFirstCard() {
        repository.storedCards = [
            card("熊本熊", plans: [plan(until: day(2026, 12, 31))]),
            card("永豐", plans: [plan(until: day(2026, 12, 31))])
        ]
        let viewModel = makeViewModel()

        _ = viewModel.check()
        let template = viewModel.renew()

        XCTAssertEqual(template?.name, "熊本熊")
        XCTAssertEqual(repository.storedCards[0].plans?[0].expiryAcknowledged, true)
        XCTAssertNil(repository.storedCards[1].plans?[0].expiryAcknowledged)
        XCTAssertEqual(makeViewModel().check()?.renewTitle, "為「永豐」設定新一期")
    }

    /// 範本沿用所有設定，只清掉起迄日與已提示，識別碼全部換新。
    func testTheRenewalTemplateKeepsSettingsButNotDatesOrIDs() {
        let bonus = CardPlan.Bonus(rate: 6, cap: 500, label: "指定店家", capPeriod: .statementCycle)
        var old = plan(from: day(2026, 7, 1), until: day(2026, 12, 31), acknowledged: true)
        old.bonus = bonus
        old.note = "需登錄"
        let expired = card("熊本熊", plans: [old], closingDay: 15)

        let template = PlanExpiryViewModel.renewalTemplate(from: expired)

        XCTAssertNil(template.id)
        XCTAssertEqual(template.name, "熊本熊")
        XCTAssertEqual(template.statementClosingDay, 15)
        let renewed = template.plans?.first
        XCTAssertNotEqual(renewed?.id, old.id)
        XCTAssertEqual(renewed?.bonus, bonus)
        XCTAssertEqual(renewed?.note, "需登錄")
        XCTAssertNil(renewed?.validFrom)
        XCTAssertNil(renewed?.validUntil)
        XCTAssertNil(renewed?.expiryAcknowledged)
    }
}
