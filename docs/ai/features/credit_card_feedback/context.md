# Credit Card Feedback — Context

Current-state facts only. Planned changes live in `plan.md`.

## Purpose

When the user pays by credit card, the app shows how much feedback (回饋) that purchase earns and how much of the card's feedback limit is left, so they can pick the card that still has room.

## Main Files

- `Card.swift` — the stored card: `name`, `id`, `plans`, and an optional `statementClosingDay`. `percent`, `limit`, `feedbackMoney`, `feedbackRemaining` are legacy fields kept for decoding.
- `CardPlan.swift` — a plan: name, base rate, optional base cap, optional bonus (rate, cap, label), note.
- `FeedbackCalculator.swift` — pure quote and remaining-amount functions; counts only entries in the current cap period; the 1.5% fee constant.
- `FeedbackPeriod.swift` — `CapPeriod` (campaign, calendarMonth, statementCycle, quarter) and the pure function that returns the period containing a date.
- `CardPlanMigration.swift` — at launch, turns a card without plans into one plan and attaches its entries to it.
- `CardRepository.swift` — `FileCardRepository`, a property list file named `cards` in Documents. One file shared by every trip.
- `CardSetViewModel.swift` / `CardSetViewController.swift` — add or edit a card: its name and one block per plan (base, base cap, bonus switch with rate, cap and condition, note). Blocks are rebuilt only when a plan is added or removed or a bonus is switched.
- `CardListViewModel.swift` / `CardListViewController.swift` — 設定 → 管理信用卡. Lists cards, opens a card for editing on tap, and deletes them on 完成.
- `IdentityMigration.swift` — at launch, gives an `id` to every card and every shopping item in every trip that lacks one.
- `DetailViewModel.swift` — 購買明細. Plan picker (one item per plan), 符合加碼 switch, quote display, and the ledger entry added after a purchase is saved.
- `FeedbackEntry.swift` — one ledger entry: card, plan, date, total, base and bonus amounts, purchase.
- `FeedbackLedgerRepository.swift` — `FileFeedbackLedgerRepository`, a property list file named `cardFeedback`, shared by every trip.
- `FeedbackLedgerMigration.swift` — at launch, turns each card's pre-ledger used amount into one entry.
- `ShoppingItem.swift` — a purchase with an optional `id`. `payType` stores `現金` or the **card's name**. It does not reference the card by identity yet.

## Data Flow

1. `DetailViewModel.loadCards()` reads all cards and the ledger, and builds one menu item per plan (`<card>[・<plan>] <base>%[＋<bonus>%]`).
2. `cardSelected(at:)` shows the remaining caps and `FeedbackCalculator.quote` (gross base, bonus if 符合加碼 is on, fee on a second line).
3. `saveTapped()` appends the item to the current trip's shopping list. Only after that save succeeds, a `FeedbackEntry` with the plan, base and bonus amounts is appended to the ledger. Cards are not written.
4. Deleting that purchase in 消費紀錄 removes its entry; deleting the card in 管理信用卡 removes all of the card's entries.

## Known Limits Of The Current Model

- Periods are cut by purchase date; banks often use the posting date, so purchases near a boundary may be counted in a different period than the bank does.
- There is no validity period. A card keeps earning at its rate after the bank's campaign ends.
- Purchases saved before the ledger have no entry, so deleting them gives nothing back.
- Entries recorded before plans hold the **net** amount (after subtracting 1.5), so old usage counts slightly lower than a bank would count it.
- `Card.feedbackMoney` and `feedbackRemaining` are legacy fields. Only `FeedbackLedgerMigration` and card saving still touch `feedbackRemaining`.

## Dependencies

- Price is the TWD amount computed on the compute screen (`ShoppingItem.price`).
- `ShoppingItem.purchasedAt` exists for items saved after the day-section change; older items have no date.
- Shopping lists are stored per trip (`TripContentStore`); cards are not.
