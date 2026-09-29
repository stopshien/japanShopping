//
//  CardSetViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

final class CardSetViewModelTests: XCTestCase {

    private var repository: CardRepositoryStub!
    private var viewModel: CardSetViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        repository = CardRepositoryStub()
        viewModel = CardSetViewModel(repository: repository)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        repository = nil
        super.tearDown()
    }

    private func fillValidCard(rate: String = "3.5", cap: String = "5000") {
        viewModel.input.nameChanged("測試卡")
        viewModel.input.planFieldChanged(.baseRate, at: 0, text: rate)
        viewModel.input.planFieldChanged(.baseCap, at: 0, text: cap)
    }

    private var forms: [CardPlanForm] {
        var forms: [CardPlanForm] = []
        viewModel.output.planForms.sink { forms = $0 }.store(in: &cancellables)
        return forms
    }

    private var isEnabled: Bool {
        var isEnabled = false
        viewModel.output.isAddEnabled.sink { isEnabled = $0 }.store(in: &cancellables)
        return isEnabled
    }

    // MARK: - 新增按鈕啟用條件

    /// 上限改為選填（留白為無上限），必填的只剩名稱與趴數。
    func testAddIsEnabledOnceTheNameAndRateAreFilled() {
        viewModel.input.nameChanged("測試卡")
        XCTAssertFalse(isEnabled, "只填名稱時不應啟用")

        viewModel.input.planFieldChanged(.baseRate, at: 0, text: "3")
        XCTAssertTrue(isEnabled)
    }

    func testAddIsDisabledWhenTheNameIsOnlyWhitespace() {
        viewModel.input.nameChanged("   ")
        viewModel.input.planFieldChanged(.baseRate, at: 0, text: "3")

        XCTAssertFalse(isEnabled)
    }

    func testTurningOnTheBonusRequiresItsRate() {
        fillValidCard()
        viewModel.input.bonusToggled(at: 0, isOn: true)
        XCTAssertFalse(isEnabled, "開了加碼就要填加碼趴數")

        viewModel.input.planFieldChanged(.bonusRate, at: 0, text: "6")
        XCTAssertTrue(isEnabled)
    }

    func testSeveralPlansEachNeedAName() {
        fillValidCard()
        viewModel.input.addPlanTapped()
        viewModel.input.planFieldChanged(.baseRate, at: 1, text: "2")
        XCTAssertFalse(isEnabled)

        viewModel.input.planFieldChanged(.name, at: 0, text: "玩旅刷")
        viewModel.input.planFieldChanged(.name, at: 1, text: "假日刷")
        XCTAssertTrue(isEnabled)
    }

    // MARK: - 表單結構

    func testANewCardStartsWithOneUnnamedPlan() {
        XCTAssertEqual(forms, [CardPlanForm(showsName: false, hasBonus: false, canRemove: false, values: [:])])
        XCTAssertNil(viewModel.output.prefillName)
        XCTAssertEqual(viewModel.output.title, "新增信用卡")
    }

    func testAddingAPlanShowsNamesAndAllowsRemoving() {
        viewModel.input.addPlanTapped()

        XCTAssertEqual(forms.count, 2)
        XCTAssertTrue(forms.allSatisfy { $0.showsName && $0.canRemove })

        viewModel.input.removePlan(at: 1)
        XCTAssertEqual(forms.count, 1)
        XCTAssertFalse(forms[0].canRemove)
        viewModel.input.removePlan(at: 0)
        XCTAssertEqual(forms.count, 1, "至少要留一個方案")
    }

    /// 重建區塊時要帶回已打的文字。
    func testRebuiltFormsKeepTheTypedValues() {
        viewModel.input.planFieldChanged(.baseRate, at: 0, text: "3.3")
        viewModel.input.bonusToggled(at: 0, isOn: true)

        XCTAssertEqual(forms[0].values[.baseRate], "3.3")
        XCTAssertTrue(forms[0].hasBonus)
    }

    // MARK: - 新增

    func testAddingCreatesACardWithOnePlan() {
        var didSave = false
        viewModel.output.didSave.sink { didSave = true }.store(in: &cancellables)

        fillValidCard()
        viewModel.input.addTapped()

        XCTAssertTrue(didSave)
        let card = try? XCTUnwrap(repository.storedCards.first)
        XCTAssertEqual(card?.name, "測試卡")
        XCTAssertNotNil(card?.id, "新卡一建立就有識別碼")
        XCTAssertEqual(card?.plans?.count, 1)
        XCTAssertEqual(card?.plans?.first?.name, "")
        XCTAssertEqual(card?.plans?.first?.baseRate, 3.5)
        XCTAssertEqual(card?.plans?.first?.baseCap, 5000)
        XCTAssertNil(card?.plans?.first?.bonus)
        XCTAssertEqual(card?.feedbackRemaining, 5000, "舊欄位仍寫入，額度是滿的")
    }

    func testAnEmptyCapMeansNoCap() {
        fillValidCard(cap: "")
        viewModel.input.addTapped()

        XCTAssertNil(repository.storedCards.first?.plans?.first?.baseCap)
    }

    func testAddingABonusAndASecondPlan() {
        fillValidCard(rate: "2.5", cap: "")
        viewModel.input.planFieldChanged(.name, at: 0, text: "日本")
        viewModel.input.bonusToggled(at: 0, isOn: true)
        viewModel.input.planFieldChanged(.bonusRate, at: 0, text: "6")
        viewModel.input.planFieldChanged(.bonusCap, at: 0, text: "500")
        viewModel.input.planFieldChanged(.bonusLabel, at: 0, text: "指定店家")
        viewModel.input.addPlanTapped()
        viewModel.input.planFieldChanged(.name, at: 1, text: "國內")
        viewModel.input.planFieldChanged(.baseRate, at: 1, text: "1")
        viewModel.input.addTapped()

        let plans = repository.storedCards.first?.plans ?? []
        XCTAssertEqual(plans.map(\.name), ["日本", "國內"])
        XCTAssertEqual(plans.first?.bonus, CardPlan.Bonus(rate: 6, cap: 500, label: "指定店家"))
        XCTAssertNil(plans.last?.bonus)
        XCTAssertNotEqual(plans.first?.id, plans.last?.id)
    }

    func testAddingKeepsExistingCards() {
        repository.storedCards = [Card.withPlan(name: "舊卡", rate: 2, cap: 1000)]

        fillValidCard()
        viewModel.input.addTapped()

        XCTAssertEqual(repository.storedCards.map(\.name), ["舊卡", "測試卡"])
    }

    // MARK: - 編輯

    func testEditingPrefillsTheNameAndPlans() {
        let bonus = CardPlan.Bonus(rate: 6, cap: nil, label: "指定店家")
        let card = Card.withPlan(name: "熊本熊", rate: 2.5, cap: 500, bonus: bonus)
        viewModel = CardSetViewModel(editingCard: card, repository: repository)

        XCTAssertEqual(viewModel.output.prefillName, "熊本熊")
        XCTAssertEqual(viewModel.output.title, "編輯信用卡")
        XCTAssertEqual(viewModel.output.confirmTitle, "儲存")
        XCTAssertEqual(forms[0].values[.baseRate], "2.5")
        XCTAssertEqual(forms[0].values[.baseCap], "500")
        XCTAssertEqual(forms[0].values[.bonusRate], "6")
        XCTAssertEqual(forms[0].values[.bonusCap], "")
        XCTAssertTrue(forms[0].hasBonus)
        XCTAssertTrue(isEnabled)
    }

    /// 方案 id 要沿用，回饋明細才對得上；卡片 id 不變，其他卡不受影響。
    func testEditKeepsTheCardAndPlanIDs() {
        let cardID = UUID()
        let planID = UUID()
        let card = Card.withPlan(name: "玉山", rate: 3.5, cap: 500, id: cardID, planID: planID)
        let other = Card.withPlan(name: "台新", rate: 3.3, cap: nil)
        repository.storedCards = [card, other]
        viewModel = CardSetViewModel(editingCard: card, repository: repository)

        viewModel.input.nameChanged("玉山熊本熊")
        viewModel.input.planFieldChanged(.baseRate, at: 0, text: "8.5")
        viewModel.input.planFieldChanged(.baseCap, at: 0, text: "1000")
        viewModel.input.addTapped()

        let edited = repository.storedCards[0]
        XCTAssertEqual(edited.id, cardID)
        XCTAssertEqual(edited.name, "玉山熊本熊")
        XCTAssertEqual(edited.plans?.first?.id, planID)
        XCTAssertEqual(edited.plans?.first?.baseRate, 8.5)
        XCTAssertEqual(edited.plans?.first?.baseCap, 1000)
        XCTAssertEqual(repository.storedCards[1], other)
    }

    /// 舊欄位維持「上限 − 已用」，尚未轉成明細的舊卡才不會多出或少掉已用額度。
    func testEditKeepsTheLegacyUsedAmount() {
        var card = Card.withPlan(name: "玉山", rate: 3.5, cap: 500)
        card.feedbackRemaining = 200
        repository.storedCards = [card]
        viewModel = CardSetViewModel(editingCard: card, repository: repository)

        viewModel.input.planFieldChanged(.baseCap, at: 0, text: "1000")
        viewModel.input.addTapped()

        XCTAssertEqual(repository.storedCards[0].limit, 1000)
        XCTAssertEqual(repository.storedCards[0].feedbackRemaining, 700)
    }

    func testEditingACardThatNoLongerExistsReportsAnError() {
        viewModel = CardSetViewModel(editingCard: Card.withPlan(name: "玉山", rate: 3.5, cap: 500), repository: repository)
        var message: String?
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.addTapped()

        XCTAssertEqual(message, "找不到這張信用卡，可能已被刪除")
        XCTAssertEqual(repository.saveCallCount, 0)
    }

    // MARK: - 上限週期

    private var showsClosingDay: Bool {
        var shows = false
        viewModel.output.showsClosingDay.sink { shows = $0 }.store(in: &cancellables)
        return shows
    }

    func testCapPeriodsAreSavedAndCampaignIsStoredAsNil() {
        fillValidCard()
        viewModel.input.capPeriodChanged(.base, at: 0, period: .calendarMonth)
        viewModel.input.bonusToggled(at: 0, isOn: true)
        viewModel.input.planFieldChanged(.bonusRate, at: 0, text: "6")
        viewModel.input.capPeriodChanged(.bonus, at: 0, period: .quarter)
        viewModel.input.addTapped()

        let plan = repository.storedCards.first?.plans?.first
        XCTAssertEqual(plan?.baseCapPeriod, .calendarMonth)
        XCTAssertEqual(plan?.bonus?.capPeriod, .quarter)

        viewModel = CardSetViewModel(repository: repository)
        fillValidCard()
        viewModel.input.addTapped()
        XCTAssertNil(repository.storedCards.last?.plans?.first?.baseCapPeriod, "不重置存成 nil，和舊資料一致")
    }

    /// 選了「每期帳單」才需要結帳日，而且必須填。
    func testAStatementCycleNeedsAClosingDay() {
        fillValidCard()
        XCTAssertFalse(showsClosingDay)

        viewModel.input.capPeriodChanged(.base, at: 0, period: .statementCycle)
        XCTAssertTrue(showsClosingDay)
        XCTAssertFalse(isEnabled)

        viewModel.input.closingDayChanged("15")
        XCTAssertTrue(isEnabled)
        viewModel.input.addTapped()

        XCTAssertEqual(repository.storedCards.first?.statementClosingDay, 15)
    }

    func testAnInvalidClosingDayReportsAnError() {
        var message: String?
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        fillValidCard()
        viewModel.input.capPeriodChanged(.base, at: 0, period: .statementCycle)
        viewModel.input.closingDayChanged("32")
        viewModel.input.addTapped()

        XCTAssertEqual(message, "帳單結帳日請輸入 1 到 31 的數字")
        XCTAssertTrue(repository.storedCards.isEmpty)
    }

    /// 加碼關掉時，它的週期不再需要結帳日。
    func testATurnedOffBonusDoesNotNeedAClosingDay() {
        fillValidCard()
        viewModel.input.bonusToggled(at: 0, isOn: true)
        viewModel.input.capPeriodChanged(.bonus, at: 0, period: .statementCycle)
        XCTAssertTrue(showsClosingDay)

        viewModel.input.bonusToggled(at: 0, isOn: false)
        XCTAssertFalse(showsClosingDay)
    }

    func testEditingPrefillsThePeriodsAndClosingDay() {
        var card = Card.withPlan(
            name: "玉山", rate: 2.5, cap: 1000,
            bonus: CardPlan.Bonus(rate: 6, cap: 500, label: "", capPeriod: .statementCycle)
        )
        card.plans?[0].baseCapPeriod = .calendarMonth
        card.statementClosingDay = 20
        viewModel = CardSetViewModel(editingCard: card, repository: repository)

        XCTAssertEqual(forms[0].baseCapPeriod, .calendarMonth)
        XCTAssertEqual(forms[0].bonusCapPeriod, .statementCycle)
        XCTAssertEqual(viewModel.output.prefillClosingDay, "20")
        XCTAssertTrue(showsClosingDay)
    }

    // MARK: - 回饋起迄日

    private var taipei: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return calendar
    }

    private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        taipei.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    /// 選到的日期存成當天 0 點；清除後為不限。
    func testDatesAreSavedAsDays() {
        viewModel = CardSetViewModel(repository: repository, calendar: taipei)
        fillValidCard()
        viewModel.input.planDateChanged(.validFrom, at: 0, date: day(2026, 7, 1, 15))
        viewModel.input.planDateChanged(.validUntil, at: 0, date: day(2026, 12, 31, 9))
        viewModel.input.addTapped()

        let plan = repository.storedCards.first?.plans?.first
        XCTAssertEqual(plan?.validFrom, day(2026, 7, 1))
        XCTAssertEqual(plan?.validUntil, day(2026, 12, 31))
        XCTAssertEqual(viewModel.output.dateText(plan?.validUntil), "2026/12/31")
        XCTAssertEqual(viewModel.output.dateText(nil), "")
    }

    func testAnEndBeforeTheStartReportsAnError() {
        var message: String?
        viewModel = CardSetViewModel(repository: repository, calendar: taipei)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        fillValidCard()
        viewModel.input.planDateChanged(.validFrom, at: 0, date: day(2026, 7, 1))
        viewModel.input.planDateChanged(.validUntil, at: 0, date: day(2026, 6, 30))
        viewModel.input.addTapped()

        XCTAssertEqual(message, "回饋結束日不能早於開始日")
        XCTAssertTrue(repository.storedCards.isEmpty)
    }

    /// 改了結束日就是新的期限，到期時要重新提示；沒改則維持已提示。
    func testChangingTheEndDateClearsTheAcknowledgement() {
        var card = Card.withPlan(name: "玉山", rate: 2.5, cap: nil)
        card.plans?[0].validUntil = day(2026, 12, 31)
        card.plans?[0].expiryAcknowledged = true
        repository.storedCards = [card]

        viewModel = CardSetViewModel(editingCard: card, repository: repository, calendar: taipei)
        viewModel.input.addTapped()
        XCTAssertEqual(repository.storedCards[0].plans?[0].expiryAcknowledged, true)

        viewModel = CardSetViewModel(editingCard: repository.storedCards[0], repository: repository, calendar: taipei)
        viewModel.input.planDateChanged(.validUntil, at: 0, date: day(2027, 6, 30))
        viewModel.input.addTapped()
        XCTAssertNil(repository.storedCards[0].plans?[0].expiryAcknowledged)
    }

    /// 「設定新一期」：欄位帶入範本，標題是新增，存成另一張新卡。
    func testATemplateIsSavedAsANewCard() {
        let old = Card.withPlan(name: "熊本熊", rate: 2.5, cap: 500)
        repository.storedCards = [old]
        let template = PlanExpiryViewModel.renewalTemplate(from: old)

        viewModel = CardSetViewModel(template: template, repository: repository)
        XCTAssertEqual(viewModel.output.prefillName, "熊本熊")
        XCTAssertEqual(viewModel.output.title, "新增信用卡")
        XCTAssertEqual(forms[0].values[.baseRate], "2.5")
        XCTAssertNil(forms[0].validUntil)

        viewModel.input.addTapped()

        XCTAssertEqual(repository.storedCards.count, 2)
        XCTAssertNotEqual(repository.storedCards[1].id, old.id)
        XCTAssertNotEqual(repository.storedCards[1].plans?[0].id, old.plans?[0].id)
    }

    // MARK: - 驗證與錯誤

    /// 遷移前這裡是 Double(text)! ，非數字輸入會直接崩潰。
    func testNonNumericRateReportsErrorInsteadOfCrashing() {
        var message: String?
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        fillValidCard(rate: "三趴")
        viewModel.input.addTapped()

        XCTAssertEqual(message, "回饋趴數請輸入數字")
        XCTAssertTrue(repository.storedCards.isEmpty)
    }

    func testNonNumericCapReportsError() {
        var message: String?
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        fillValidCard(cap: "五千")
        viewModel.input.addTapped()

        XCTAssertEqual(message, "回饋上限請輸入數字，或留白表示無上限")
        XCTAssertTrue(repository.storedCards.isEmpty)
    }

    func testNonNumericBonusRateReportsError() {
        var message: String?
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        fillValidCard()
        viewModel.input.bonusToggled(at: 0, isOn: true)
        viewModel.input.planFieldChanged(.bonusRate, at: 0, text: "六")
        viewModel.input.addTapped()

        XCTAssertEqual(message, "加碼趴數請輸入數字")
    }

    func testAddTappedDoesNothingWhenFieldsAreIncomplete() {
        viewModel.input.nameChanged("測試卡")
        viewModel.input.addTapped()

        XCTAssertEqual(repository.saveCallCount, 0)
    }

    func testSaveFailureReportsErrorAndDoesNotFinish() {
        repository.saveError = StubError.failure
        var didSave = false
        var message: String?
        viewModel.output.didSave.sink { didSave = true }.store(in: &cancellables)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        fillValidCard()
        viewModel.input.addTapped()

        XCTAssertFalse(didSave)
        XCTAssertEqual(message, "信用卡儲存失敗，請再試一次")
    }
}
