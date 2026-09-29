# Credit Card Feedback — Plan

Goal: represent how cards really pay feedback (uncapped base + capped bonus, cap periods, switchable plans, campaign end dates) and keep remaining amounts correct across months, edits, and deletions.

Research behind this plan is in `references.md`.

## Target Model

```text
Card
├── id: UUID                      // new; assigned by migration
├── name
├── foreignFeePercent: Double?    // phase 6 only (deferred); until then the fee is 1.5
├── plans: [CardPlan]?            // new; nil only for not-yet-migrated files
└── legacy: percent, limit, feedbackMoney, feedbackRemaining   // kept for decoding, no longer read

CardPlan                          // built in phase 3
├── id: UUID
├── name                          // "" for a single-plan card, 「玩旅刷」 for Richart
├── baseRate
├── baseCap: Double?              // gross; nil = uncapped; migrated cards keep their old limit here
├── bonus: CardPlan.Bonus?
├── baseCapPeriod / bonus.capPeriod   // phase 4: calendarMonth | statementCycle(closingDay) | quarter | campaign
├── validFrom: Date?              // phase 5; nil = no start date
├── validUntil: Date?             // phase 5; nil = no end date
├── expiryAcknowledged: Bool?     // phase 5; set once the user dismisses the expiry alert
└── note: String                  // free text for conditions the app cannot check

CardPlan.Bonus
├── rate
├── cap: Double?                  // gross feedback amount; nil = uncapped
└── label: String                 // shown on the qualify switch, e.g. 「指定店家」

FeedbackEntry                     // new file 「cardFeedback」, shared by all trips
├── id: UUID
├── cardID, planID
├── date
├── amount                        // total; entries from before phase 3 only have this (net)
├── baseAmount, bonusAmount       // gross, rounded to cents; nil on older entries
└── shoppingItemID: UUID?         // nil for the migrated legacy balance

ShoppingItem (new optional fields)
└── id: UUID?                     // the ledger links to purchases by this; no cardID / planID needed
```

## Phases

Each phase ships on its own, keeps the app working, and updates tests plus the behavior contract.

### Phase 1 — Identity and editing (low risk) — done 2026-09-29

- Add `Card.id` and `ShoppingItem.id` (optional). A one-time migration assigns them.
- Add an edit mode to the card screen (name, rate, limit), reached by tapping a row in 管理信用卡.
- No change to how feedback is calculated.
- As built: `IdentityMigration` runs at every launch in `AppScreenFactory.init` and writes only when an `id` is missing. A new purchase gets its `id` in `DetailViewModel.saveTapped`. Editing keeps the used amount (`limit - feedbackRemaining`).

### Phase 2 — Feedback ledger — done 2026-09-29

- Add `FeedbackLedgerRepository` with the `cardFeedback` file.
- `DetailViewModel` records a `FeedbackEntry` after a successful save instead of editing `feedbackRemaining`. The purchase stores `cardID`.
- Remaining is computed from entries. The migration turns each card's used amount (`limit - feedbackRemaining`) into one legacy entry, so nothing resets.
- Deleting a purchase in the shopping list removes its entries, so the feedback goes back to the card.
- Deleting a card deletes its entries.
- As built: entries have a single `amount` (the net amount counted against the cap, as before); phase 3 adds gross base and bonus amounts. The purchase does not store `cardID`; the entry stores `shoppingItemID`, which is enough to refund. A purchase never earns more than the card has left, and a negative result counts as zero. Deleting a trip keeps its entries.

### Phase 3 — Plans, base and bonus — done 2026-09-29

- Migration converts each card into one plan: `baseRate = percent`, no bonus, and the old limit kept as a campaign-period cap. Behavior matches today.
- The card editor gains a plan list; the plan editor has rate, optional bonus (rate, cap, period, closing day, label), end date, and note.
- In 購買明細 the picker lists every current plan (`Richart・玩旅刷 3.3%`). If the plan has a bonus, a 「符合加碼（指定店家）」 switch appears. It is **off every time** the screen opens; the last choice is not remembered, so the estimate never overstates.
- 「這筆回饋」 shows the **gross** amount (base + bonus). The foreign transaction fee is listed separately beneath it, e.g. 「這筆回饋 NT$ 33・海外手續費 NT$ 15」. The subtitle shows the bonus left this period, worded as an estimate.
- As built, differing from the above:
  - The base rate can also have a cap (`baseCap`), because a pre-plan card's single cap covered all of its feedback. The migration puts the old limit there; without it, migrated cards would lose their cap.
  - Plans are edited inline on the card screen, one block per plan, instead of a separate plan editor, so a single-plan card stays one screen.
  - The cap period and closing day are **not** in the form yet; they arrive with phase 4, when they are actually calculated. Every cap is currently a whole-time cap.
  - The fee is on its own line (「這筆回饋 NT$ 132.01」 / 「海外手續費 NT$ 35.15」), because on one line the fee amount wrapped mid-number.
  - Caps are per plan, not per card.

### Phase 4 — Cap periods — done 2026-09-29

- A pure `FeedbackPeriod` type returns the period containing a date for each `capPeriod`. A statement closing day past the end of a month uses that month's last day.
- Remaining bonus = cap − Σ bonus entries in the current period.
- Tests cover month ends, closing days 28–31, quarter edges, and time zones.
- As built: `CapPeriod` is a String enum stored as `baseCapPeriod` and `bonus.capPeriod`; nil means 不重置. The closing day is on the card (`statementClosingDay`), since a card's plans share one statement. The form has a four-segment period picker under each cap, and the closing-day field appears directly under the first picker set to 每期帳單 (moved there from the card-name block on 2026-09-30, because a field appearing at the top of a scrolled form went unnoticed). `FeedbackPeriod` lives in `FeedbackPeriod.swift`; `FeedbackCalculator` takes the closing day, date and calendar, defaulting to now and `.current`.

### Phase 5 — Campaign dates and renewal — done 2026-09-29

- Plans have an optional start and end date (回饋起迄日). A plan outside its dates is **hidden** from the 購買明細 picker; a card with no current plan is hidden entirely.
- 管理信用卡 still lists expired cards, marked 「已過期」, or 「剩 N 天」 within 14 days of the end date.
- **Expiry alert.** Checked every time the app becomes active: a cold launch and every return from the background. A cold launch alone is not enough, because iOS keeps the app suspended for days and a whole trip can pass without one. On a cold launch the alert waits until the launch animation has finished and the compute screen is showing. If some plan has expired without being acknowledged, an alert names it:
  - 「知道了」 sets `expiryAcknowledged`; that plan never raises the alert again.
  - 「設定新一期」 also sets `expiryAcknowledged`, then opens the add-card screen **prefilled** from the expired card: name, plans, rates, bonus, cap, cap period, closing day, and notes. Only the start and end dates are left empty for the user to fill in.
  - Several expired plans are listed in one alert; 「設定新一期」 then applies to the first, and the rest stay unacknowledged for the next time.
- There is no second alert in 購買明細. A plan acknowledged at launch is simply absent from the picker.
- Why at launch rather than at the card picker: at the picker the user is usually at the till and will dismiss it, while at launch there is time to enter the next period before shopping. Campaigns usually end on 6/30 or 12/31, so the next launch is often the start of the next trip.
- As built: dates are entered in text fields with a wheel date picker and 清除／完成 on the keyboard toolbar; blank means unlimited, so a renewal really starts with empty dates. 知道了 acknowledges every plan in the alert. The alert logic is `PlanExpiryViewModel`; `ScreenFactory.makePlanExpiryAlert` builds the `UIAlertController`; `SceneDelegate` decides when it may be shown. Changing a plan's end date clears its acknowledgement.
- The renewed period is saved as a **new card**. The expired card keeps its history and its ledger entries, and the user can delete it from 管理信用卡. Rows show the period (e.g. `2026/7/1–12/31`) so two cards with the same name can be told apart.

### Phase 6 — Per-card foreign fee (deferred)

- Use `Card.foreignFeePercent` instead of the fixed 1.5. Default stays 1.5.
- Not scheduled. Decided 2026-09-28 to do it later; `foreignFeePercent` is not added until then.

## Risky Areas

- **Persistence.** Card and shopping-item decoding must survive every intermediate version. Add a decode test for each old shape before migrating.
- **Behavior contract.** Entries about cumulative deduction, deduct-after-save, and card-list merge-on-return change in phases 2–3. Update them in the same commit.
- **Card list edits.** Deletions currently wait for 完成 while additions merge in. Editing adds a third path; keep the pending-deletion guarantee.
- **Cross-trip totals.** The ledger is the only place that sees every trip. Do not compute period totals by scanning shopping lists.
- **Legacy purchases.** Items saved before phase 2 have no `cardID`; deleting them cannot refund. That is accepted and documented.

## Decisions (2026-09-28, 2026-09-29)

1. 「這筆回饋」 shows the gross amount, with the foreign transaction fee listed separately.
2. The bonus-qualify switch starts off every time; the last choice is not remembered.
3. Expired plans are hidden from the picker. An alert tells the user once per expired plan and offers to set up the next period, prefilled except for the start and end dates.
4. The per-card foreign fee (phase 6) is deferred.
5. The expiry alert is checked whenever the app becomes active (cold launch and return from background), shown only once the compute screen is up, and not repeated in 購買明細.
6. 「設定新一期」 creates a new card rather than adding a period to the old card.
