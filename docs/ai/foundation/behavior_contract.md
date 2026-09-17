# Behavior Contract

Rules this app enforces that the code alone does not explain, plus the record of where today's behavior deliberately differs from the app's original Storyboard/MVC version.

Read this before changing anything that looks like an oddity. Several entries below look like bugs and are not.

## Behavior That Must Not Change Silently

Each entry names the test that locks it. If a change makes one of these tests fail, the change is wrong until proven otherwise — do not edit the test to match the new behavior.

- **Deleting is only persisted on an explicit confirm.** Card list deletions save on 編輯完成; shopping list deletions save on Done. Leaving with the back button discards them, so a mis-tapped delete can be abandoned. `CardListViewModelTests`, `ShoppingListViewModelTests`.
- **The shopping list total is recalculated from scratch after every deletion**, never accumulated. `ShoppingListViewModelTests`.
- **Deleting a shopping list row deletes its photo file**, but only after the list has been saved successfully, so a failed save never destroys an image. `ShoppingListViewModelTests`.
- **The card feedback calculation subtracts 1.5 from the card percentage** before applying it: `(percent - 1.5) * price * 0.01`. Both the feedback amount and the remaining limit are rounded to cents before being stored, otherwise floating point error accumulates across purchases. `DetailViewModelTests`.
- **A new card's `feedbackRemaining` starts equal to its `limit`**, and `feedbackMoney` starts at 0. `CardSetViewModelTests`.
- **The tax multiplier follows the currency, not the user.** Japanese yen uses 1.08, Korean won uses 1.1. There is no separate tax-rate picker; choosing a currency chooses its country's rate. `Currency.taxMultiplier`, `PriceBreakdownTests`.
- **Japan's 1.08 is the reduced rate for food and drink.** Japan's standard consumption tax has been 10% since 2019. 8% was kept deliberately because this app is used mostly for groceries and snacks — it is a choice, not an oversight.
- **The exchange rate is derived as TWD / foreign currency and kept to four significant digits**, not four decimal places. Korean won is an order of magnitude smaller than yen, so a fixed decimal place would leave it with three significant digits and a 0.2% error. `ExchangeRateDecodingTests`.
- **The rate's update time is parsed with `en_US_POSIX`** and displayed in `Asia/Taipei`. Without the POSIX locale it fails to parse on non-English devices. `ComputeViewModelTests`.
- **The on-disk property list format of `ShoppingItem` and `Card`.** The stored keys are the property names, so renaming a property silently breaks every existing user's saved data. `PersistenceFormatTests`, `FileShoppingListRepositoryTests`, `FileCardRepositoryTests`.
- **Photos are referenced by bare filename, never by absolute path.** The app container path changes between installs. `FileImageStoreTests`.

## Why The Code Looks Like This

- **`PayMethod` is separate from `ShoppingItem.payType`.** The original code kept only the `payType` string, and selecting a card overwrote it with the **card's name** — so `payType == "信用卡"` was never true once a card was chosen, and the code worked around it by inspecting whether the card button was hidden. `PayMethod` models the choice; `payType` is only the value that gets persisted. `DetailViewModelTests` locks both.
- **`ComputeViewModel` keeps `.receive(on: DispatchQueue.main)` even though it makes tests asynchronous.** Removing it would let the rate be written from the URLSession background thread while the main thread reads it. The tests wait for the main queue instead.
- **`PriceText` is the only place money is formatted.** It shows 0 to 2 decimal places with no grouping separator and a fixed `en_US_POSIX` locale, so output does not change with device settings. Every money string in the app goes through it.

## Deliberate Departures From The Original App

Currency support was added after the migration; entries below marked (幣別) describe that change.


Each entry is behavior that intentionally differs from the Storyboard/MVC version. They are listed so nobody "restores" them as bugs.

- **(幣別) The rate label names the currency**, e.g. `日幣匯率：0.2047` rather than `匯率：0.2047`, because two currencies are now selectable.
- **(幣別) Switching currency clears the previous conversion result.** The old result belongs to the old rate and tax rate, so carrying it forward would let a yen price be saved as a won purchase.
- **Card setup rejects non-numeric input instead of crashing.** The original used `Double(moneyBack)!` and `Double(limit)!`, so non-numeric input crashed the app.
- **Choosing 信用卡 without picking a card no longer crashes.** `PayMethod.card(index:)` makes "credit card, none chosen" a representable state.
- **Returning from a card screen resets the selected card.** The original kept the old index, which could point past the end of the array after a deletion.
- **Converting before the rate arrives reports an error instead of producing 0.** The original started with a rate of `0`, so tapping 換算 too early silently produced 0 元. Likewise 使用未稅價格 / 使用含稅價格 do nothing until a conversion has been made, rather than carrying a 0 price forward.
- **Pay type defaults to `現金`.** The picker has always displayed 現金 as its initial row, but `didSelectRow` never fires for it, so an item saved without touching the picker stored an empty `payType`.
- **Deleting a shopping list row deletes its photo file.** The original left the JPEG behind forever.
- **An empty shopping list shows `你已經花了0.0$`.** The original skipped the calculation when the list was empty, leaving the storyboard's design-time placeholder `總花費` on screen.

## Open Debt

- **The exchange-rate API key is not a secret.** It moved out of Swift source into the `EXCHANGE_RATE_API_KEY` build setting, surfaced through `Info.plist`, which only made it configurable. It still ships inside the app bundle and is still present in this repository's git history. Rotating the key and proxying the request through a backend is the only real fix.
- **Clearing the entry screen after tapping Done in the list** was a wish in the original code's header comment. It was never built.

## Update Discipline

- When behavior in the first section changes on purpose, move the entry to Deliberate Departures and say so in the commit message.
- When a piece of debt is closed, delete its entry rather than marking it done.
- Do not add migration bookkeeping here. This file records what the app does and why, not how it got there.
