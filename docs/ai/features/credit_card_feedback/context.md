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
- `DetailViewModel.swift` — 購買明細. Card picker, feedback calculation, and the deduction after a purchase is saved.
- `ShoppingItem.swift` — a purchase with an optional `id`. `payType` stores `現金` or the **card's name**. It does not reference the card by identity yet.

## Data Flow

1. `DetailViewModel.loadCards()` reads all cards and builds the menu (`<name> <percent>%`).
2. `cardSelected(at:)` computes `feedbackMoney = round2((percent - 1.5) * price * 0.01)` and shows `剩餘回饋 <feedbackRemaining>`.
3. `saveTapped()` appends the item to the current trip's shopping list. Only after that save succeeds, `persistSelectedCardFeedback()` sets `feedbackRemaining = max(0, round2(feedbackRemaining - feedbackMoney))` and saves every card.

## Known Limits Of The Current Model

- `feedbackRemaining` is a running balance. It never resets, so a monthly or per-statement cap cannot be represented.
- A card has one rate and one cap. Real cards have an uncapped base rate and a capped bonus, sometimes several switchable plans. See `references.md`.
- There is no validity period. A card keeps earning at its rate after the bank's campaign ends.
- Deleting or editing a shopping list item never gives feedback back to the card, because the item does not know which card it used, only its name.
- The cap is consumed by the **net** amount (after subtracting 1.5), while banks cap the **gross** bonus amount.
- `feedbackMoney` is a transient value stored on `Card` only to pass it from selection to save.

## Dependencies

- Price is the TWD amount computed on the compute screen (`ShoppingItem.price`).
- `ShoppingItem.purchasedAt` exists for items saved after the day-section change; older items have no date.
- Shopping lists are stored per trip (`TripContentStore`); cards are not.
