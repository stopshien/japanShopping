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
- `ShoppingListViewController` + `ShoppingListViewModel` — replaces `ListViewController` and `ListTableViewCell`

Legacy, not yet migrated:
- `ComputeViewController` — rate fetch, tax arithmetic, and navigation all inline
- `DetailViewController` — holds `lists`, `cards`, `numberOfCards`; owns the feedback calculation

Migrated infrastructure:
- `japanShoppingTests` unit test target exists, hosted by the app, with a shared scheme at `japanShopping.xcodeproj/xcshareddata/xcschemes/japanShopping.xcscheme`
- `PersistenceFormatTests` locks the on-disk property-list format of `List` and `Card`
- `ExchangeRateDecodingTests` locks the exchange-rate API response shape and the JPY→TWD derivation

- `Card` is a plain `Codable` type in `Card.swift`; persistence lives in `CardRepository`
- `ShoppingItem` (renamed from `List`) is a plain `Codable` type; persistence lives in `ShoppingListRepository`
- `ImageStore` owns photo files; `DetailViewController` writes through it instead of touching `FileManager`
- `DocumentsDirectory` is the single place that resolves the Documents directory
- `AppColor.brand` replaces the olive colour that was duplicated across storyboard scenes
- `PriceText` is the single place that formats money
- `UIViewController.addTapToDismissKeyboard()` is the shared keyboard-dismiss helper

Legacy infrastructure:
- `Main.storyboard` still holds the Compute and Detail scenes
- The exchange-rate API key is hard-coded in source
- `ShoppingListFactory` bridges the two legacy screens to the migrated shopping list; delete it once both are migrated

### Bridging while the migration is in progress

`DetailViewController` is still legacy but already drives every migrated screen. It holds a `FileCardRepository`, a `FileShoppingListRepository`, and a `FileImageStore`, constructs the child ViewModels, and refreshes itself through the child's `onFinish` closure. This replaced the `unwindToCardVSetViewController(_:)` unwind segue, which is gone.

`ComputeViewController` and `DetailViewController` reach the shopping list through `showShoppingListTapped(_:)`, an `@IBAction` that replaced the two `show` segues to the old `ListViewController` scene. Both build the screen through `UIViewController.makeShoppingListViewController()` in `ShoppingListFactory.swift`.

When these two screens are migrated, the repositories become injected dependencies, `onFinish` becomes a route output, and `ShoppingListFactory` is deleted.

## Known Behavior To Preserve

Carry these forward deliberately during migration; do not drop them by accident.

- `ListViewController` deliberately saves only when the user taps Done, so a mis-tapped deletion can be abandoned.
- The card feedback calculation subtracts 1.5 from the card percentage before applying it.
- Tax conversion uses a 1.08 multiplier, applied in both directions depending on the selected segment.
- `DetailViewController` currently decides pay type by checking whether the card button is hidden, because comparing `payType` against the string `"信用卡"` did not work. Find the real cause during migration rather than reproducing the workaround.
- A new card's `feedbackRemaining` starts equal to its `limit`, and `feedbackMoney` starts at 0. Locked by `CardSetViewModelTests`.
- Deleting a card in the card list is only persisted when the user taps 編輯完成. Leaving with the back button discards the deletions. Locked by `CardListViewModelTests`.
- Deleting a shopping list row is only persisted when the user taps Done. Leaving with the back button discards the deletions. Locked by `ShoppingListViewModelTests`.
- The shopping list total is recalculated from scratch after every deletion, never accumulated. Locked by `ShoppingListViewModelTests`.
- Tax conversion produces prices such as `206.0`, and the UI shows that raw value. `PriceText` centralises this so it can be changed in one place later.

## Intentional Behavior Changes

Each entry is a place where migrated behavior deliberately differs from the legacy screen.

- **Card setup rejects non-numeric input instead of crashing.** The legacy `CardSetViewController` used `Double(moneyBack)!` and `Double(limit)!`, so entering anything non-numeric crashed the app. `CardSetViewModel` now reports a validation message instead. Reproducing a crash was not a defensible reading of "behavior must be identical".
- **Returning from a card screen resets the selected card.** `reloadCards()` sets `numberOfCards = -1`. The legacy unwind kept the old index, which could point past the end of the array after a deletion and trap in `saveToListButton`.
- **Deleting a shopping list row now deletes its photo file.** The legacy screen left the JPEG behind forever. The deletion happens only after the list has been saved successfully, so a failed save never destroys an image.
- **An empty shopping list shows `你已經花了0.0$`.** The legacy screen skipped the calculation when the list was empty on load, leaving the storyboard's design-time placeholder `總花費` on screen. A programmatic view has no design-time text, and the delete path already produced the computed string.

## Update Discipline
- Move a screen from the legacy list to the migrated list in the same commit that migrates it.
- Delete a "known behavior" entry only when the behavior is intentionally removed, and say so in the commit message.
- When the last screen is migrated, replace this file with a short note and remove the legacy carve-outs from the foundation rules.
