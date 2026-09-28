# Credit Card Feedback — Context

Current-state facts only. Planned changes live in `plan.md`.

## Purpose

When the user pays by credit card, the app shows how much feedback (回饋) that purchase earns and how much of the card's feedback limit is left, so they can pick the card that still has room.

## Main Files

- `Card.swift` — the stored card: `name`, `percent`, `limit`, `feedbackMoney`, `feedbackRemaining`, and an optional `id`.
- `CardRepository.swift` — `FileCardRepository`, a property list file named `cards` in Documents. One file shared by every trip.
- `CardSetViewModel.swift` / `CardSetViewController.swift` — add a card, or edit one when created with `editingCard` (name, percent, limit).
- `CardListViewModel.swift` / `CardListViewController.swift` — 設定 → 管理信用卡. Lists cards, opens a card for editing on tap, and deletes them on 完成.
- `IdentityMigration.swift` — at launch, gives an `id` to every card and every shopping item in every trip that lacks one.
- `DetailViewModel.swift` — 購買明細. Card picker, feedback calculation, and the ledger entry added after a purchase is saved.
- `FeedbackEntry.swift` — one ledger entry (card, date, amount, purchase) and `Card.remainingFeedback(in:)`.
- `FeedbackLedgerRepository.swift` — `FileFeedbackLedgerRepository`, a property list file named `cardFeedback`, shared by every trip.
- `FeedbackLedgerMigration.swift` — at launch, turns each card's pre-ledger used amount into one entry.
- `ShoppingItem.swift` — a purchase with an optional `id`. `payType` stores `現金` or the **card's name**. It does not reference the card by identity yet.

## Data Flow

1. `DetailViewModel.loadCards()` reads all cards and the ledger, and builds the menu (`<name> <percent>%`).
2. `cardSelected(at:)` computes `min(max(0, round2((percent - 1.5) * price * 0.01)), remaining)` and shows `剩餘回饋 <limit − Σ entries>`.
3. `saveTapped()` appends the item to the current trip's shopping list. Only after that save succeeds, a `FeedbackEntry` pointing at the item is appended to the ledger. Cards are not written.
4. Deleting that purchase in 消費紀錄 removes its entry; deleting the card in 管理信用卡 removes all of the card's entries.

## Known Limits Of The Current Model

- Every entry counts against the cap forever; there are no cap periods yet, so a monthly or per-statement cap cannot be represented.
- A card has one rate and one cap. Real cards have an uncapped base rate and a capped bonus, sometimes several switchable plans. See `references.md`.
- There is no validity period. A card keeps earning at its rate after the bank's campaign ends.
- Purchases saved before the ledger have no entry, so deleting them gives nothing back.
- The cap is consumed by the **net** amount (after subtracting 1.5), while banks cap the **gross** bonus amount. Entries store that net amount until phase 3.
- `Card.feedbackMoney` and `feedbackRemaining` are legacy fields. Only `FeedbackLedgerMigration` and card editing still touch `feedbackRemaining`.

## Dependencies

- Price is the TWD amount computed on the compute screen (`ShoppingItem.price`).
- `ShoppingItem.purchasedAt` exists for items saved after the day-section change; older items have no date.
- Shopping lists are stored per trip (`TripContentStore`); cards are not.
