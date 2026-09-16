# Migration Status

The repository is migrating from Storyboard-based MVC to programmatic UIKit with MVVM and Combine.

This file exists so agents can tell the difference between "code that violates the rules" and "code that has not been migrated yet". Keep it current; it is the only place that records migration progress.

## Rule Application

- **New code follows the target architecture** in `ios_architecture.md`, `ui_and_layout.md`, and `persistence_and_networking.md`. There is no grace period for new files.
- **Legacy screens keep working** until they are migrated. Do not partially convert a screen as a side effect of an unrelated fix.
- When touching a legacy screen for a small fix, make the fix in place in the legacy style. Propose the migration separately.
- Never mix a migration and a behavior change in the same commit.

## Target State
- Programmatic UIKit views, no Storyboard scenes
- One ViewModel per screen, UIKit-free, protocol-defined Input / Output
- Protocol-defined services for persistence, image storage, and networking
- Initializer injection, no property assignment across controllers
- A unit test target covering ViewModels and services

## Current State

Migrated screens:
- `CardSetViewController` + `CardSetViewModel` — programmatic UI, validates input, writes through `CardRepository`
- `CardListViewController` + `CardListViewModel` — replaces `EditCardsTableViewController`

Legacy, not yet migrated:
- `ComputeViewController` — rate fetch, tax arithmetic, and navigation all inline
- `DetailViewController` — holds `lists`, `cards`, `numberOfCards`; owns feedback calculation and image writing
- `ListViewController` — owns total-spend calculation and save timing

Migrated infrastructure:
- `japanShoppingTests` unit test target exists, hosted by the app, with a shared scheme at `japanShopping.xcodeproj/xcshareddata/xcschemes/japanShopping.xcscheme`
- `PersistenceFormatTests` locks the on-disk property-list format of `List` and `Card`
- `ExchangeRateDecodingTests` locks the exchange-rate API response shape and the JPY→TWD derivation

- `Card` is a plain `Codable` type in `Card.swift`; persistence lives in `CardRepository`
- `DocumentsDirectory` is the single place that resolves the Documents directory
- `UIViewController.addTapToDismissKeyboard()` is the shared keyboard-dismiss helper

Legacy infrastructure:
- `Main.storyboard` still holds the Compute, Detail, and List scenes
- `List` still carries its own static save/read methods
- The exchange-rate API key is hard-coded in source

### Bridging while the migration is in progress

`DetailViewController` is still legacy but already drives the two migrated screens. It holds a `FileCardRepository`, constructs the child ViewModels, and refreshes itself through the child's `onFinish` closure. This replaced the `unwindToCardVSetViewController(_:)` unwind segue, which is gone. When `DetailViewController` is migrated, the repository becomes an injected dependency and `onFinish` becomes a route output.

## Known Behavior To Preserve

Carry these forward deliberately during migration; do not drop them by accident.

- `ListViewController` deliberately saves only when the user taps Done, so a mis-tapped deletion can be abandoned.
- The card feedback calculation subtracts 1.5 from the card percentage before applying it.
- Tax conversion uses a 1.08 multiplier, applied in both directions depending on the selected segment.
- `DetailViewController` currently decides pay type by checking whether the card button is hidden, because comparing `payType` against the string `"信用卡"` did not work. Find the real cause during migration rather than reproducing the workaround.
- A new card's `feedbackRemaining` starts equal to its `limit`, and `feedbackMoney` starts at 0. Locked by `CardSetViewModelTests`.
- Deleting a card in the card list is only persisted when the user taps 編輯完成. Leaving with the back button discards the deletions. Locked by `CardListViewModelTests`.

## Intentional Behavior Changes

Each entry is a place where migrated behavior deliberately differs from the legacy screen.

- **Card setup rejects non-numeric input instead of crashing.** The legacy `CardSetViewController` used `Double(moneyBack)!` and `Double(limit)!`, so entering anything non-numeric crashed the app. `CardSetViewModel` now reports a validation message instead. Reproducing a crash was not a defensible reading of "behavior must be identical".
- **Returning from a card screen resets the selected card.** `reloadCards()` sets `numberOfCards = -1`. The legacy unwind kept the old index, which could point past the end of the array after a deletion and trap in `saveToListButton`.

## Update Discipline
- Move a screen from the legacy list to the migrated list in the same commit that migrates it.
- Delete a "known behavior" entry only when the behavior is intentionally removed, and say so in the commit message.
- When the last screen is migrated, replace this file with a short note and remove the legacy carve-outs from the foundation rules.
