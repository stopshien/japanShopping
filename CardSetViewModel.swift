//
//  CardSetViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

protocol CardSetViewModelType {
    var input: CardSetViewModelInput { get }
    var output: CardSetViewModelOutput { get }
}

/// 方案表單中的欄位。
enum CardPlanField: CaseIterable {
    case name
    case baseRate
    case baseCap
    case bonusRate
    case bonusCap
    case bonusLabel
    case note
}

/// 畫面上一個方案區塊要顯示的樣子與目前的文字。
/// 只在區塊增減或加碼開關切換時重新發出，打字不會觸發重建。
struct CardPlanForm: Equatable {
    /// 只有一個方案時不需要方案名稱。
    let showsName: Bool
    let hasBonus: Bool
    /// 至少要留一個方案。
    let canRemove: Bool
    let values: [CardPlanField: String]
}

protocol CardSetViewModelInput {
    func nameChanged(_ text: String)
    func planFieldChanged(_ field: CardPlanField, at index: Int, text: String)
    func bonusToggled(at index: Int, isOn: Bool)
    func addPlanTapped()
    func removePlan(at index: Int)
    func addTapped()
}

protocol CardSetViewModelOutput {
    /// 「新增信用卡」或「編輯信用卡」。
    var title: String { get }
    /// 送出按鈕的文字。
    var confirmTitle: String { get }
    /// 編輯時的卡片名稱，新增時為 nil。
    var prefillName: String? { get }
    var planForms: AnyPublisher<[CardPlanForm], Never> { get }
    var isAddEnabled: AnyPublisher<Bool, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    /// 新增或編輯存檔成功。
    var didSave: AnyPublisher<Void, Never> { get }
}

// MARK: - Errors

enum CardSetError: LocalizedError, Equatable {
    case invalidPercent
    case invalidLimit
    case invalidBonusPercent
    case saveFailed
    case cardNotFound

    var errorDescription: String? {
        switch self {
        case .invalidPercent:
            return "回饋趴數請輸入數字"
        case .invalidLimit:
            return "回饋上限請輸入數字，或留白表示無上限"
        case .invalidBonusPercent:
            return "加碼趴數請輸入數字"
        case .saveFailed:
            return "信用卡儲存失敗，請再試一次"
        case .cardNotFound:
            return "找不到這張信用卡，可能已被刪除"
        }
    }
}

// MARK: - ViewModel

final class CardSetViewModel: CardSetViewModelType {

    /// 還沒存檔的方案，欄位保留使用者打的文字。
    private struct PlanDraft {
        /// 編輯既有方案時沿用它的 id，回饋明細才對得上。
        var id: UUID?
        var hasBonus = false
        var values: [CardPlanField: String] = [:]

        func text(_ field: CardPlanField) -> String { values[field] ?? "" }
    }

    private let repository: CardRepository
    /// 編輯中的卡片；nil 代表新增。
    private let editingCard: Card?

    private var name = ""
    private var drafts: [PlanDraft]

    private let planFormsSubject = CurrentValueSubject<[CardPlanForm], Never>([])
    private let isAddEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didSaveSubject = PassthroughSubject<Void, Never>()

    let prefillName: String?

    init(editingCard: Card? = nil, repository: CardRepository) {
        self.repository = repository
        self.editingCard = editingCard
        prefillName = editingCard?.name
        name = editingCard?.name ?? ""
        drafts = (editingCard?.plans ?? []).map(Self.draft(from:))
        if drafts.isEmpty {
            drafts = [PlanDraft()]
        }
        publishForms()
        refreshAddEnabled()
    }

    var input: CardSetViewModelInput { self }
    var output: CardSetViewModelOutput { self }

    // MARK: - Private

    private static func draft(from plan: CardPlan) -> PlanDraft {
        var values: [CardPlanField: String] = [
            .name: plan.name,
            .baseRate: PriceText.amount(plan.baseRate),
            .baseCap: plan.baseCap.map(PriceText.amount) ?? "",
            .note: plan.note
        ]
        if let bonus = plan.bonus {
            values[.bonusRate] = PriceText.amount(bonus.rate)
            values[.bonusCap] = bonus.cap.map(PriceText.amount) ?? ""
            values[.bonusLabel] = bonus.label
        }
        return PlanDraft(id: plan.id, hasBonus: plan.bonus != nil, values: values)
    }

    private func publishForms() {
        let showsName = drafts.count > 1
        planFormsSubject.send(drafts.map {
            CardPlanForm(showsName: showsName, hasBonus: $0.hasBonus, canRemove: drafts.count > 1, values: $0.values)
        })
    }

    /// 必填：卡片名稱、每個方案的基本回饋趴數；多個方案時要有方案名稱；開了加碼就要填加碼趴數。
    /// 上限都是選填，留白代表無上限。
    private func refreshAddEnabled() {
        let plansFilled = drafts.allSatisfy { draft in
            !draft.text(.baseRate).isEmpty
                && (drafts.count == 1 || !draft.text(.name).isEmpty)
                && (!draft.hasBonus || !draft.text(.bonusRate).isEmpty)
        }
        isAddEnabledSubject.send(!name.isEmpty && plansFilled)
    }

    /// 留白為 nil（無上限）；有填但不是數字時丟出錯誤。
    private static func optionalAmount(_ text: String) throws -> Double? {
        guard !text.isEmpty else { return nil }
        guard let value = Double(text), value >= 0 else { throw CardSetError.invalidLimit }
        return value
    }

    private static func rate(_ text: String, error: CardSetError) throws -> Double {
        guard let value = Double(text), value >= 0 else { throw error }
        return value
    }

    private func buildPlans() throws -> [CardPlan] {
        let single = drafts.count == 1
        return try drafts.map { draft in
            var bonus: CardPlan.Bonus?
            if draft.hasBonus {
                bonus = CardPlan.Bonus(
                    rate: try Self.rate(draft.text(.bonusRate), error: .invalidBonusPercent),
                    cap: try Self.optionalAmount(draft.text(.bonusCap)),
                    label: draft.text(.bonusLabel)
                )
            }
            return CardPlan(
                id: draft.id ?? UUID(),
                // 只有一個方案時不顯示名稱，舊的名稱也不留。
                name: single ? "" : draft.text(.name),
                baseRate: try Self.rate(draft.text(.baseRate), error: .invalidPercent),
                baseCap: try Self.optionalAmount(draft.text(.baseCap)),
                bonus: bonus,
                note: draft.text(.note)
            )
        }
    }

    /// 有 id 就以 id 比對；遷移前的卡片沒有 id，只能比對整張卡。
    private static func isSameCard(_ lhs: Card, _ rhs: Card) -> Bool {
        if let id = rhs.id { return lhs.id == id }
        return lhs == rhs
    }

    /// 回饋與剩餘額度都以 `plans` 與回饋明細計算。舊欄位 `percent`、`limit` 仍寫入第一個方案的值，
    /// `feedbackRemaining` 保持「上限 − 已用」不變，尚未轉成明細的舊卡才不會算錯。
    private static func card(_ original: Card?, name: String, plans: [CardPlan]) -> Card {
        let limit = plans.first?.baseCap ?? 0
        let used = original.map { max(0, $0.limit - $0.feedbackRemaining) } ?? 0
        return Card(
            name: name,
            percent: plans.first?.baseRate ?? 0,
            limit: limit,
            feedbackRemaining: FeedbackCalculator.roundedToCents(max(0, limit - used)),
            id: original?.id ?? UUID(),
            plans: plans
        )
    }
}

// MARK: - CardSetViewModelInput

extension CardSetViewModel: CardSetViewModelInput {

    func nameChanged(_ text: String) {
        name = text.trimmingCharacters(in: .whitespaces)
        refreshAddEnabled()
    }

    func planFieldChanged(_ field: CardPlanField, at index: Int, text: String) {
        guard drafts.indices.contains(index) else { return }
        drafts[index].values[field] = text.trimmingCharacters(in: .whitespaces)
        refreshAddEnabled()
    }

    func bonusToggled(at index: Int, isOn: Bool) {
        guard drafts.indices.contains(index), drafts[index].hasBonus != isOn else { return }
        drafts[index].hasBonus = isOn
        publishForms()
        refreshAddEnabled()
    }

    func addPlanTapped() {
        drafts.append(PlanDraft())
        publishForms()
        refreshAddEnabled()
    }

    func removePlan(at index: Int) {
        guard drafts.count > 1, drafts.indices.contains(index) else { return }
        drafts.remove(at: index)
        publishForms()
        refreshAddEnabled()
    }

    func addTapped() {
        guard isAddEnabledSubject.value else { return }

        let plans: [CardPlan]
        do {
            plans = try buildPlans()
        } catch {
            errorMessageSubject.send((error as? CardSetError ?? .invalidPercent).localizedDescription)
            return
        }

        do {
            var cards = try repository.load()
            if let editingCard {
                guard let index = cards.firstIndex(where: { Self.isSameCard($0, editingCard) }) else {
                    errorMessageSubject.send(CardSetError.cardNotFound.localizedDescription)
                    return
                }
                cards[index] = Self.card(cards[index], name: name, plans: plans)
            } else {
                // 新卡還沒有任何回饋明細，額度是滿的。
                cards.append(Self.card(nil, name: name, plans: plans))
            }
            try repository.save(cards)
            didSaveSubject.send(())
        } catch {
            errorMessageSubject.send(CardSetError.saveFailed.localizedDescription)
        }
    }
}

// MARK: - CardSetViewModelOutput

extension CardSetViewModel: CardSetViewModelOutput {

    var title: String { editingCard == nil ? "新增信用卡" : "編輯信用卡" }
    var confirmTitle: String { editingCard == nil ? "新增信用卡" : "儲存" }
    var planForms: AnyPublisher<[CardPlanForm], Never> { planFormsSubject.eraseToAnyPublisher() }
    var isAddEnabled: AnyPublisher<Bool, Never> { isAddEnabledSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didSave: AnyPublisher<Void, Never> { didSaveSubject.eraseToAnyPublisher() }
}
