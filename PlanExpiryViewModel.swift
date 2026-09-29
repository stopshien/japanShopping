//
//  PlanExpiryViewModel.swift
//  japanShopping
//

import Foundation

/// 回饋方案到期提示的內容。
struct PlanExpiryNotice: Equatable {
    let title: String
    let message: String
    /// 「設定新一期」按鈕的文字，套用在第一張到期的卡。
    let renewTitle: String
}

/// App 回到前景時檢查有沒有剛到期、還沒提示過的回饋方案。
///
/// 到期的方案已經不會出現在刷卡選單，提示是讓使用者知道卡片為什麼不見了，
/// 並可以直接用舊卡的設定建立新一期。每個方案只提示一次。
final class PlanExpiryViewModel {

    private struct ExpiredPlan {
        let cardID: UUID
        let planID: UUID
    }

    private let repository: CardRepository
    private let now: () -> Date
    private let calendar: Calendar
    /// 最近一次 `check()` 找到的到期方案，依卡片順序排列。
    private var expired: [ExpiredPlan] = []

    init(repository: CardRepository, now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
    }

    /// 有到期且尚未提示過的方案時回傳提示內容，否則為 nil。
    func check() -> PlanExpiryNotice? {
        let cards = (try? repository.load()) ?? []
        var lines: [String] = []
        expired = []
        for card in cards {
            guard let cardID = card.id else { continue }
            let plans = card.plans ?? []
            for plan in plans where plan.isExpired(on: now(), calendar: calendar) && plan.expiryAcknowledged != true {
                expired.append(ExpiredPlan(cardID: cardID, planID: plan.id))
                let name = plans.count > 1 ? "\(card.name)・\(plan.name)" : card.name
                lines.append("・\(name)（到 \(Self.dateText(plan.validUntil, calendar: calendar, now: now()))）")
            }
        }
        guard let first = expired.first, let firstCard = cards.first(where: { $0.id == first.cardID }) else {
            return nil
        }
        return PlanExpiryNotice(
            title: "回饋方案已到期",
            message: "以下方案已不會出現在刷卡選單：\n" + lines.joined(separator: "\n"),
            renewTitle: "為「\(firstCard.name)」設定新一期"
        )
    }

    /// 「知道了」：這次列出的方案都不再提示。
    func acknowledge() {
        markAcknowledged(expired)
    }

    /// 「設定新一期」：只把第一張卡的到期方案標為已提示，其餘的下次再提示。
    /// 回傳以那張卡為範本的新卡：設定都沿用，只有回饋起迄日清空、識別碼全部換新。
    func renew() -> Card? {
        guard let first = expired.first else { return nil }
        let cards = (try? repository.load()) ?? []
        guard let card = cards.first(where: { $0.id == first.cardID }) else { return nil }
        markAcknowledged(expired.filter { $0.cardID == first.cardID })
        return Self.renewalTemplate(from: card)
    }

    static func renewalTemplate(from card: Card) -> Card {
        var template = card
        template.id = nil
        template.plans = card.plans?.map { plan in
            var plan = plan
            plan.id = UUID()
            plan.validFrom = nil
            plan.validUntil = nil
            plan.expiryAcknowledged = nil
            return plan
        }
        return template
    }

    // MARK: - Private

    private func markAcknowledged(_ plans: [ExpiredPlan]) {
        guard !plans.isEmpty, var cards = try? repository.load() else { return }
        for index in cards.indices {
            guard let cardID = cards[index].id, var cardPlans = cards[index].plans else { continue }
            for planIndex in cardPlans.indices
            where plans.contains(where: { $0.cardID == cardID && $0.planID == cardPlans[planIndex].id }) {
                cardPlans[planIndex].expiryAcknowledged = true
            }
            cards[index].plans = cardPlans
        }
        try? repository.save(cards)
    }

    /// 今年的日期省略年份，例如「12/31」；其他年份寫完整，例如「2027/3/31」。
    static func dateText(_ date: Date?, calendar: Calendar, now: Date = Date()) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = calendar.isDate(date, equalTo: now, toGranularity: .year) ? "M/d" : "yyyy/M/d"
        return formatter.string(from: date)
    }
}
