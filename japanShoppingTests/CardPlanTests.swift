//
//  CardPlanTests.swift
//  japanShoppingTests
//

import XCTest
@testable import japanShopping

// MARK: - 回饋計算

final class FeedbackCalculatorTests: XCTestCase {

    private let planID = UUID()

    private func plan(rate: Double = 2.5, cap: Double? = nil, bonus: CardPlan.Bonus? = nil) -> CardPlan {
        CardPlan(id: planID, name: "", baseRate: rate, baseCap: cap, bonus: bonus, note: "")
    }

    private func entry(base: Double, bonus: Double = 0, planID: UUID? = nil) -> FeedbackEntry {
        FeedbackEntry(
            id: UUID(), cardID: UUID(), date: Date(), amount: base + bonus, shoppingItemID: nil,
            planID: planID ?? self.planID, baseAmount: base, bonusAmount: bonus
        )
    }

    /// 毛額：2.5% × 1000 = 25；手續費 1.5% × 1000 = 15 另外列。
    func testQuoteIsGrossWithTheFeeSeparate() {
        let quote = FeedbackCalculator.quote(plan: plan(), price: 1000, qualifiesForBonus: false, entries: [])

        XCTAssertEqual(quote, FeedbackQuote(base: 25, bonus: 0, fee: 15))
        XCTAssertEqual(quote.total, 25)
    }

    func testTheBonusCountsOnlyWhenQualified() {
        let bonus = CardPlan.Bonus(rate: 6, cap: nil, label: "")

        let off = FeedbackCalculator.quote(plan: plan(bonus: bonus), price: 1000, qualifiesForBonus: false, entries: [])
        let on = FeedbackCalculator.quote(plan: plan(bonus: bonus), price: 1000, qualifiesForBonus: true, entries: [])

        XCTAssertEqual(off.bonus, 0)
        XCTAssertEqual(on.bonus, 60)
        XCTAssertEqual(on.total, 85)
    }

    /// 基本與加碼各算各的上限，而且只算同一個方案的明細。
    func testEachLayerIsLimitedByItsOwnRemaining() {
        let bonus = CardPlan.Bonus(rate: 6, cap: 100, label: "")
        let entries = [entry(base: 90, bonus: 70), entry(base: 500, bonus: 500, planID: UUID())]

        let quote = FeedbackCalculator.quote(
            plan: plan(cap: 100, bonus: bonus), price: 1000, qualifiesForBonus: true, entries: entries
        )

        XCTAssertEqual(quote.base, 10)
        XCTAssertEqual(quote.bonus, 30)
    }

    func testRemainingIsNilWhenUncapped() {
        XCTAssertNil(FeedbackCalculator.remainingBase(of: plan(), in: [entry(base: 10)]))
        XCTAssertNil(FeedbackCalculator.remainingBonus(of: plan(), in: [entry(base: 10)]))
    }

    /// 上限被調低到比已用還少時，剩餘停在 0。
    func testRemainingNeverGoesBelowZero() {
        XCTAssertEqual(FeedbackCalculator.remainingBase(of: plan(cap: 100), in: [entry(base: 300)]), 0)
    }

    /// 方案出現前的明細沒有 baseAmount，整筆 amount 都算基本回饋。
    func testLegacyEntriesCountTheirWholeAmountAsBase() {
        let legacy = FeedbackEntry(id: UUID(), cardID: UUID(), date: Date(), amount: 0.9, shoppingItemID: nil, planID: planID)

        XCTAssertEqual(FeedbackCalculator.remainingBase(of: plan(cap: 500), in: [legacy]), 499.1)
        XCTAssertEqual(FeedbackCalculator.remainingBonus(
            of: plan(bonus: CardPlan.Bonus(rate: 1, cap: 50, label: "")), in: [legacy]
        ), 50)
    }
}

// MARK: - 遷移

final class CardPlanMigrationTests: XCTestCase {

    private var cardRepository: CardRepositoryStub!
    private var ledgerRepository: FeedbackLedgerRepositoryStub!

    override func setUp() {
        super.setUp()
        cardRepository = CardRepositoryStub()
        ledgerRepository = FeedbackLedgerRepositoryStub()
    }

    override func tearDown() {
        ledgerRepository = nil
        cardRepository = nil
        super.tearDown()
    }

    private func runMigration() {
        CardPlanMigration.run(cardRepository: cardRepository, ledgerRepository: ledgerRepository)
    }

    /// 舊卡的趴數成為基本回饋、上限成為基本回饋上限，行為與轉換前相同。
    func testALegacyCardBecomesOnePlan() {
        cardRepository.storedCards = [Card(name: "gogo", percent: 3.5, limit: 500, feedbackRemaining: 500, id: UUID())]

        runMigration()

        let plan = cardRepository.storedCards.first?.plans?.first
        XCTAssertEqual(cardRepository.storedCards.first?.plans?.count, 1)
        XCTAssertEqual(plan?.name, "")
        XCTAssertEqual(plan?.baseRate, 3.5)
        XCTAssertEqual(plan?.baseCap, 500)
        XCTAssertNil(plan?.bonus)
    }

    func testAZeroLimitBecomesUncapped() {
        cardRepository.storedCards = [Card(name: "卡", percent: 3, limit: 0, feedbackRemaining: 0, id: UUID())]

        runMigration()

        XCTAssertNil(cardRepository.storedCards.first?.plans?.first?.baseCap)
    }

    func testEntriesWithoutAPlanAreGivenTheCardsPlan() {
        let cardID = UUID()
        cardRepository.storedCards = [Card(name: "卡", percent: 3.5, limit: 500, feedbackRemaining: 499.1, id: cardID)]
        ledgerRepository.storedEntries = [
            FeedbackEntry(id: UUID(), cardID: cardID, date: Date(), amount: 0.9, shoppingItemID: nil)
        ]

        runMigration()

        let plan = cardRepository.storedCards[0].plans![0]
        XCTAssertEqual(ledgerRepository.storedEntries.first?.planID, plan.id)
        XCTAssertEqual(FeedbackCalculator.remainingBase(of: plan, in: ledgerRepository.storedEntries), 499.1)
    }

    /// 已經有方案的卡片不動；再跑一次也不會換掉方案 id。
    func testRunningTwiceChangesNothing() {
        cardRepository.storedCards = [Card(name: "卡", percent: 3.5, limit: 500, feedbackRemaining: 500, id: UUID())]

        runMigration()
        let planID = cardRepository.storedCards[0].plans?.first?.id
        runMigration()

        XCTAssertEqual(cardRepository.storedCards[0].plans?.first?.id, planID)
        XCTAssertEqual(cardRepository.saveCallCount, 1)
        XCTAssertEqual(ledgerRepository.saveCallCount, 0)
    }

    /// 上次替卡片建好方案後明細沒存成功，這次要補上，不能留下對不到方案的明細。
    func testUnstampedEntriesAreFixedOnALaterRun() {
        let cardID = UUID()
        let planID = UUID()
        cardRepository.storedCards = [Card.withPlan(name: "卡", rate: 3.5, cap: 500, id: cardID, planID: planID)]
        ledgerRepository.storedEntries = [
            FeedbackEntry(id: UUID(), cardID: cardID, date: Date(), amount: 1, shoppingItemID: nil)
        ]

        runMigration()

        XCTAssertEqual(ledgerRepository.storedEntries.first?.planID, planID)
        XCTAssertEqual(cardRepository.saveCallCount, 0)
    }
}

// MARK: - 存檔格式

final class CardPlanPersistenceTests: XCTestCase {

    func testACardWithPlansSurvivesAPropertyListRoundTrip() throws {
        let bonus = CardPlan.Bonus(rate: 6, cap: nil, label: "指定店家")
        let card = Card(
            name: "熊本熊", percent: 2.5, limit: 0, feedbackRemaining: 0, id: UUID(),
            plans: [CardPlan(id: UUID(), name: "", baseRate: 2.5, baseCap: nil, bonus: bonus, note: "需登錄")]
        )

        let data = try PropertyListEncoder().encode([card])

        XCTAssertEqual(try PropertyListDecoder().decode([Card].self, from: data), [card])
    }

    /// 方案出現前存下的明細沒有 planID、baseAmount、bonusAmount，必須仍能讀取。
    func testALegacyEntryStillDecodes() throws {
        let legacy: [String: Any] = [
            "id": UUID().uuidString, "cardID": UUID().uuidString, "date": Date(), "amount": 0.9
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: legacy, format: .xml, options: 0)

        let decoded = try PropertyListDecoder().decode(FeedbackEntry.self, from: data)

        XCTAssertEqual(decoded.amount, 0.9)
        XCTAssertNil(decoded.planID)
        XCTAssertEqual(decoded.countedBase, 0.9)
        XCTAssertEqual(decoded.countedBonus, 0)
    }
}
