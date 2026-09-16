# Quality And Delivery

## Code Quality
- Prefer `final` unless inheritance is intentionally required.
- Prefer narrow access control, usually `private`.
- Avoid force unwraps. `Double(text)!`, `date!`, and `as! Cell` are existing hazards — do not add new ones, and remove them when migrating a file.
- Never index an array with a computed offset without checking bounds. Prefer `for item in items` over `for i in 0...items.count-1`, which traps on an empty array.
- Use `[weak self]` in every escaping closure and every `sink`.
- Prefer clarity over cleverness.
- Produce complete, compilable code rather than partial snippets, unless the task explicitly asks for a sketch.

## Comments
- Explanatory comments are written in Traditional Chinese; keep that voice.
- Write `// MARK:` section names in English.
- Add comments only when they explain intent that the code does not show.
- A comment documenting deliberate behavior must be preserved, or promoted into `behavior_contract.md`, before the code is rewritten.
- Remove a comment that no longer matches the code instead of leaving it stale.

## Testing
- ViewModels and services must be unit-testable: no UIKit import, all dependencies injected as protocols.
- Add tests for ViewModel logic and service parsing when migrating or adding a screen.
- Test doubles live in the `japanShoppingTests` target, never in production files.
- Run the suite with `xcodebuild test -project japanShopping.xcodeproj -scheme japanShopping -destination 'platform=iOS Simulator,name=iPhone 16'`.
- `PersistenceFormatTests` guards the saved-file format. If a change to `List` or `Card` breaks it, that change breaks existing users' data — fix the model or state the migration plan, do not edit the test to match.

## Verification
- Build with `xcodebuild -project japanShopping.xcodeproj -scheme japanShopping -destination 'platform=iOS Simulator,name=iPhone 16' build`, or run it in the simulator.
- Exercise the affected screen. A binding or layout error only surfaces at runtime.
- State plainly what was verified and what was not. Do not claim a screen works if it was not run.

## Git And Review
- Write commit messages in the format defined in `docs/ai/foundation/commit_message_conventions.md`.
- Keep each commit focused on one reviewable goal.
- Do not commit `xcuserdata/` or other per-developer Xcode state.
- Do not commit unless the user asks.

## Change Hygiene
- Do not mix unrelated refactors with feature work unless they are tightly coupled.
- Do not reformat or rename across a file you were asked to make a small change in.
- Update `docs/ai/foundation/behavior_contract.md` in the same commit that changes a behaviour it records.
- Treat stale AI guidance as technical debt and clean it up promptly.
