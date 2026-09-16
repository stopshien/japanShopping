# Swift File Organization

## File Scope
- Keep one primary type per file unless a small related helper clearly belongs beside it.
- Name the file after its primary type (`ListViewController.swift` contains `ListViewController`).
- Do not place unrelated helper types, mocks, or large utility code in production files.
- `List.swift` currently holds both `List` and `Card`. Keep new model types out of it; give a new model its own file.

## Preferred Type Order
- type declaration
- `@IBOutlet` properties
- stored properties
- initializers
- lifecycle (`viewDidLoad`, `viewWillAppear`, …)
- `@IBAction` methods
- other methods
- private helpers
- protocol conformances in extensions

## Extensions
- Use extensions to separate protocol conformances and focused responsibilities.
- Keep each extension limited to a single responsibility or protocol.
- Do not use extensions to hide logic that should live in another type.

## MARK Organization
- Use `// MARK: - ...` to separate outlets, lifecycle, actions, helpers, and protocol conformances.
- Keep section names in English.
- Avoid vague section names such as `Misc` or `Helper` when a more specific name is possible.
- Avoid excessive fragmentation in very small files.

## Naming
- Types are `UpperCamelCase`; properties and methods are `lowerCamelCase`.
- Existing outlets such as `TypeOfPay` and methods such as `UISet()` violate this. Do not copy the pattern into new code; rename only when the change is the point of the task, and update the storyboard connection in the same change.
- Prefer descriptive names over abbreviations (`japaneseYenToTaiwanDollar` over `JYPToTWD`) in new code.

## Formatting
- Use 4-space indentation.
- Put a space after `:` in type annotations and around binary operators.
- Put a space between a closing `)` and `{`.
- Match the surrounding file when the local style is already consistent.

## Access Control
- Default to `private` for helper methods and stored properties that no other type reads.
- Properties assigned by a pushing controller during navigation must stay internal; document why with a short comment when it is not obvious.
- Use `private(set)` when write access should stay internal to the owner type.
- Prefer `final class` for view controllers and cells unless subclassing is intended.
