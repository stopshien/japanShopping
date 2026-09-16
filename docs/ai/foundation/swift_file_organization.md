# Swift File Organization

## File Scope
- Keep one primary type per file, named after that type.
- A screen is split across files: `<Screen>ViewController.swift`, `<Screen>ViewModel.swift`, and the protocol declarations beside the ViewModel.
- Models, services, and view controllers do not share a file.
- Do not place mocks or test doubles in production files.

## Preferred Type Order

For a view controller:
- type declaration
- injected dependencies (`viewModel`)
- `cancellables`
- private view properties
- initializers
- lifecycle
- setup methods
- binding
- action handlers
- private helpers
- protocol conformances in extensions

For a ViewModel:
- type declaration and `Input` / `Output` conformance
- injected services
- private subjects and state
- initializer
- `input` / `output` accessors
- private logic
- extensions conforming to the `Input` and `Output` protocols

## Extensions
- Use extensions to separate protocol conformances and focused responsibilities.
- Keep each extension limited to a single responsibility or protocol.
- Do not use extensions to hide logic that belongs in another type.

## MARK Organization
- Use `// MARK: - ...` to separate properties, lifecycle, setup, binding, actions, and protocol conformances.
- Keep section names in English.
- Avoid vague section names such as `Misc` or `Helper`.
- Avoid excessive fragmentation in very small files.

## Naming
- Types are `UpperCamelCase`; properties and methods are `lowerCamelCase`.
- Prefer descriptive names over abbreviations: `yenToTaiwanDollarRate`, not `JYPToTWD`.
- Name a publisher for the value it carries, not for the mechanism.

## Formatting
- Use 4-space indentation.
- Put a space after `:` in type annotations and around binary operators.
- Put a space between a closing `)` and `{`.
- Match the surrounding file when the local style is already consistent.

## Access Control
- Default to `private`. A property that no other type reads must be `private`.
- Subjects are always `private`; expose `AnyPublisher` instead.
- Use `private(set)` when write access should stay internal to the owner type.
- Mark view controllers, cells, ViewModels, and services `final` unless subclassing is intended.
- Mark `init(coder:)` unavailable on programmatic view controllers rather than leaving a live `fatalError` path.
