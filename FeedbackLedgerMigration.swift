//
//  FeedbackLedgerMigration.swift
//  japanShopping
//

import Foundation

/// 把回饋明細出現前已用掉的額度（上限 − 剩餘）轉成一筆明細，額度才不會歸零。
///
/// 必須在 `IdentityMigration` 之後執行，明細要靠卡片的 id 對應。
/// 已經有明細的卡片視為遷移過，不會重複加上。
enum FeedbackLedgerMigration {

    static func run(
        cardRepository: CardRepository,
        ledgerRepository: FeedbackLedgerRepository,
        now: Date = Date()
    ) {
        guard let cards = try? cardRepository.load(),
              let entries = try? ledgerRepository.load() else { return }

        let migratedCardIDs = Set(entries.map(\.cardID))
        let legacyEntries: [FeedbackEntry] = cards.compactMap { card in
            guard let id = card.id, !migratedCardIDs.contains(id) else { return nil }
            let used = (max(0, card.limit - card.feedbackRemaining) * 100).rounded() / 100
            guard used > 0 else { return nil }
            return FeedbackEntry(id: UUID(), cardID: id, date: now, amount: used, shoppingItemID: nil)
        }

        guard !legacyEntries.isEmpty else { return }
        try? ledgerRepository.save(entries + legacyEntries)
    }
}
