# iOS Architecture Baseline

This repository is a single-target UIKit app with the following stack:
- Swift 5
- iOS 16.2 deployment target (`japanShopping.xcodeproj`)
- UIKit + Storyboard
- MVC (`UIViewController` owns screen logic)
- No third-party dependency manager: no CocoaPods, no Swift Package Manager, no Carthage

## Architecture Constraints
- Keep the existing MVC shape. Do not convert screens to MVVM, Combine, SwiftUI, or RxSwift unless the user explicitly asks.
- Keep models as plain `Codable` value types without UIKit imports (`List.swift`, `ExchangeRate.swift`).
- Keep persistence and decoding logic on the model type, not scattered across view controllers.
- Keep a `UIViewController` responsible for one screen. Do not let one controller drive another controller's state beyond the handoff described below.
- Prefer feature-local helpers over new global singletons or registries.

## Screen Map
- `ComputeViewController` — JPY input, tax mode, exchange-rate fetch, produces a `List` item
- `DetailViewController` — product name, pay type, card selection, photo selection, appends to the list
- `ListViewController` — shopping list display, total spend, row deletion
- `CardSetViewController` — creates a `Card`
- `EditCardsTableViewController` — lists and deletes `Card` values
- `ListTableViewCell` — list row rendering

## Navigation And Data Handoff
- Screens are pushed with `storyboard?.instantiateViewController(withIdentifier:)` + `navigationController?.pushViewController(_:animated:)`.
- Use the storyboard identifier `"\(TypeName.self)"` form where the existing code already does; do not mix in new ad-hoc identifier strings for the same screen.
- Data is handed to the next controller by assigning its properties before or immediately after the push. Keep those properties explicit and typed.
- `DetailViewController` receives unwind segues through `unwindToCardVSetViewController(_:)`. Keep the unwind contract intact when touching card creation.
- Do not add a new navigation mechanism (coordinator, router, delegate chain) for a single screen without approval.

## State Ownership
- `List` owns shopping-item persistence. `Card` owns credit-card persistence.
- A controller that mutates `cards` or `lists` must save through the model's static save method, not by writing files directly.
- Keep the "save on explicit user action" behavior intact: `ListViewController` deliberately saves only when the user taps Done, so deletions can be abandoned.
