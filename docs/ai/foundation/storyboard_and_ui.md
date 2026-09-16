# Storyboard And UI Conventions

## UI Construction
- Build UI in `japanShopping/Base.lproj/Main.storyboard`, not programmatically.
- Do not introduce SnapKit, SwiftUI, or programmatic Auto Layout rewrites for existing screens.
- Add programmatic layout only for views that cannot reasonably be expressed in the storyboard, and say so in the change description.

## Outlets And Actions
- Connect views through `@IBOutlet weak var` and interactions through `@IBAction`.
- Declare outlets and actions at the top of the controller, before lifecycle methods.
- Name outlets after what they show (`priceLabel`, `exchangeRateLabel`), not after their position.
- When a storyboard connection is renamed or removed in code, update the storyboard in the same change; a stale connection crashes at load time.
- Do not leave empty `@IBAction` bodies for new work. If a hook is intentionally unused, say why in a comment.

## Screen Structure
- Keep `viewDidLoad()` short: delegate assignment, data loading, then a setup method such as `UISet()`.
- Extract display configuration into named methods (`UISet()`, `cardChooseButtonSet()`, `totalSpendCount()`) instead of growing `viewDidLoad()`.
- Use `// MARK: -` to separate outlets, lifecycle, actions, helpers, and protocol conformances.
- Put `UITableViewDataSource`, `UIPickerViewDelegate`, and `UIImagePickerControllerDelegate` conformances in extensions, one responsibility per extension.

## Table Views
- Register and dequeue cells with the identifier form already used in the repository.
- Keep cell configuration inside `tableView(_:cellForRowAt:)` or a cell-owned configure method; do not perform file IO decisions elsewhere in the data source.
- Keep row deletion and the derived totals in sync; recompute totals after a mutation instead of patching the label by hand.

## Text And Formatting
- User-facing strings are Traditional Chinese.
- Format currency and percentages explicitly (`String(format: "%.2f", value)`) rather than interpolating a raw `Double`.
- Avoid scattered magic numbers. Give tax rates, fee percentages, and limits a named constant in a private `enum` near the code that uses them.

## Keyboard
- Screens with text input dismiss the keyboard via the existing tap-gesture pattern (`UITapGestureRecognizer` targeting `UIView.endEditing(_:)`). Reuse it instead of inventing a new mechanism.
