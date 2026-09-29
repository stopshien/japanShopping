//
//  CardPlanMigration.swift
//  japanShopping
//

import Foundation

/// 把方案出現前的卡片轉成「只有一個方案」的卡片，行為和轉換前一樣：
/// 趴數成為基本回饋，上限成為基本回饋的上限。
///
/// 分兩步，各自可重跑：先替沒有方案的卡片建立方案，再把沒有方案的明細歸到卡片的第一個方案。
/// 這樣就算其中一步存檔失敗，下次啟動也能接著完成，不會產生對不到方案的明細。
/// 必須在 `IdentityMigration` 與 `FeedbackLedgerMigration` 之後執行。
enum CardPlanMigration {

    static func run(cardRepository: CardRepository, ledgerRepository: FeedbackLedgerRepository) {
        guard var cards = try? cardRepository.load() else { return }

        if cards.contains(where: { $0.plans == nil }) {
            cards = cards.map(withSinglePlan)
            guard (try? cardRepository.save(cards)) != nil else { return }
        }

        guard let entries = try? ledgerRepository.load() else { return }
        let firstPlanIDs = Dictionary(
            cards.compactMap { card in card.id.flatMap { id in card.plans?.first.map { (id, $0.id) } } },
            uniquingKeysWith: { first, _ in first }
        )
        guard entries.contains(where: { $0.planID == nil && firstPlanIDs[$0.cardID] != nil }) else { return }

        let stamped = entries.map { entry -> FeedbackEntry in
            guard entry.planID == nil, let planID = firstPlanIDs[entry.cardID] else { return entry }
            var entry = entry
            entry.planID = planID
            return entry
        }
        try? ledgerRepository.save(stamped)
    }

    /// 上限為 0 或更小的舊卡視為無上限。
    private static func withSinglePlan(_ card: Card) -> Card {
        guard card.plans == nil else { return card }
        var card = card
        card.plans = [
            CardPlan(
                id: UUID(),
                name: "",
                baseRate: card.percent,
                baseCap: card.limit > 0 ? card.limit : nil,
                bonus: nil,
                note: ""
            )
        ]
        return card
    }
}
