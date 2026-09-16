# Quality And Delivery

## Code Quality
- Prefer `final` unless inheritance is intentionally required.
- Prefer narrow access control, usually `private`.
- Avoid force unwraps. `Double(text)!`, `date!`, and `as! Cell` are existing hazards — do not add new ones, and prefer `guard let` when touching that code.
- Never index an array with a computed offset without checking bounds. Prefer `for item in items` over `for i in 0...items.count-1`, which traps on an empty array.
- Prefer clarity over cleverness.
- When generating Swift changes, produce complete, compilable code rather than partial snippets, unless the task explicitly asks for a sketch.

## Comments
- Explanatory comments in this repository are written in Traditional Chinese; keep that voice when editing existing files.
- Write `// MARK:` section names in English.
- Add comments only when they explain intent that the code does not show.
- Keep a comment that documents a deliberate behavior (for example, why deletion is not saved immediately). Do not delete such notes while refactoring.
- Remove a comment that no longer matches the code instead of leaving it stale.

## Verification
- There is no test target in this repository. Verify by building the app and exercising the affected screen.
- Build with `xcodebuild -project japanShopping.xcodeproj -scheme japanShopping -destination 'platform=iOS Simulator,name=iPhone 16' build` or by running it in the simulator.
- State plainly what was verified and what was not. Do not claim a screen works if it was not run.
- Storyboard-connected changes must be checked at runtime; a broken outlet only fails when the scene loads.

## Git And Review
- Write commit messages in the format defined in `docs/ai/foundation/commit_message_conventions.md`.
- Keep each commit focused on one reviewable goal.
- Do not commit `xcuserdata/` or other per-developer Xcode state. If it is already tracked, raise it rather than sweeping it into an unrelated commit.
- Do not commit unless the user asks.

## Change Hygiene
- Do not mix unrelated refactors with feature work unless they are tightly coupled.
- Do not reformat or rename across a file you were asked to make a small change in.
- When changing behavior, update the corresponding feature-local docs in the same commit.
- Treat stale AI guidance as technical debt and clean it up promptly.
