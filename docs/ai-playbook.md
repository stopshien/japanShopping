# AI Knowledge Map for `japanShopping`

This document is the repository entrypoint for AI guidance. It is intentionally a map, not an encyclopedia.

Repository knowledge is the system of record: global guidance stays small, detailed knowledge is progressively disclosed, and feature-specific context lives next to the rules that depend on it.

## Operating Model

### Humans steer, agents execute
- Human intent should be expressed through repository-local artifacts instead of ad-hoc chat context.
- Durable engineering knowledge belongs in versioned files that agents can discover while working.
- If a rule, constraint, or design decision matters repeatedly, write it down in the repository.

### Keep the entrypoint small
- `AGENTS.md` and `CLAUDE.md` should stay short and point to this file.
- This playbook explains how guidance is organized; it does not duplicate every detailed rule.
- Durable rules belong in neutral repository docs under `docs/ai/`, not in tool-specific folders.

### Progressive disclosure
- Use the smallest stable entrypoint first.
- Load workflow guidance only when the task matches it.
- Load feature-local knowledge only when the task touches that feature.

## Repository Knowledge Layout

### Entrypoints
- `AGENTS.md`
- `CLAUDE.md`
- `docs/ai-playbook.md`

### Neutral source of truth
Path: `docs/ai/`

- `docs/ai/foundation/` — always-on repository rules
- `docs/ai/workflows/` — task-scoped guidance
- `docs/ai/features/` — feature-local knowledge

Tool-specific folders (`.claude/`, `.cursor/`) may hold thin adapters or commands, but they must not become the canonical home of the rules themselves.

### Repository landmarks
- Production Swift sources: repository root, flat, one primary type per file
  - screens: `<Screen>ViewController.swift` + `<Screen>ViewModel.swift`
  - services: `<Thing>Repository.swift`, `ImageStore.swift`, `ExchangeRateService.swift`
  - models: `ShoppingItem.swift`, `Card.swift`, `ExchangeRate.swift`, `UserProfile.swift`, `Trip.swift`
  - composition root: `ScreenFactory.swift`
  - domain values: `Currency.swift`, `TaxMode.swift` (含 `PriceBreakdown`)
  - shared helpers: `AppColor.swift`, `AppStyle.swift`, `AppView.swift`, `AppAppearance.swift`, `PriceText.swift`, `DocumentsDirectory.swift`, `UIViewController+KeyboardDismiss.swift`
- App lifecycle and resources: `japanShopping/` (`AppDelegate.swift`, `SceneDelegate.swift`, `Info.plist`, `Assets.xcassets`, `LaunchScreen.storyboard`)
- Tests: `japanShoppingTests/`
- Xcode project: `japanShopping.xcodeproj`

Note: production Swift files live at the repository root rather than inside `japanShopping/`, and there are no group folders. Keep new files consistent with this layout unless a restructure is explicitly requested.

### Architecture

Programmatic UIKit with MVVM and Combine, no third-party dependencies. There is no Storyboard. `docs/ai/foundation/behavior_contract.md` records the behaviours the app deliberately enforces — read it before treating an oddity as a bug.

### Foundational rules
Path: `docs/ai/foundation/`

- `repository_operating_model.md` — how agents load and maintain knowledge here
- `behavior_contract.md` — behaviours that must not change silently, and why the code looks the way it does
- `ios_architecture.md` — stack, MVVM layer responsibilities, ViewModel contract, navigation
- `ui_and_layout.md` — programmatic UIKit, screen structure, Combine binding rules
- `persistence_and_networking.md` — service protocols, file persistence, image storage, URLSession
- `swift_file_organization.md` — file scope, type order, `MARK:`, access control
- `commit_message_conventions.md` — commit format for this repository
- `quality_and_delivery.md` — code quality, testing, verification, change hygiene

### Workflow guidance
Path: `docs/ai/workflows/`

- `new_feature_development.md`
- `refactor_analysis.md`
- `code_review.md`

### Feature-local knowledge
Path: `docs/ai/features/<feature>/`

See `docs/ai/features/README.md` for the contract. Each feature directory is the source of truth for that feature's current knowledge:
- `context.md`: current-state facts, responsibilities, dependencies, and state flow
- `rules.md`: hard and soft constraints for safe modification
- `plan.md`: safe evolution path and refactoring sequence
- `references.md`: optional supplemental notes that are neither constraints nor plans

## Rule Selection Model

### Always-on
- Files in `foundation/` are durable repository rules.
- They should be concise, enforceable, and specific.
- Avoid prompt-style prose or one-off task instructions in foundational rules.

### Task-scoped
- Files in `workflows/` are opt-in guidance for a specific mode of work.
- They define deliverables, review focus, sequencing, and verification expectations.
- They must not silently override feature-local hard constraints.

### Feature-scoped
- Files in `features/<feature>/` are loaded when work touches that feature.
- Feature-local rules override generic workflow guidance when they are more specific.
- Do not place feature-specific facts in foundational rules.

## Authoring Standards

### Language
- Write AI-facing rules and feature knowledge in English.
- Commit messages and user-facing strings stay in Traditional Chinese.
- Existing in-code comments are Traditional Chinese; see `docs/ai/foundation/quality_and_delivery.md` for the comment language rule.

### Tool neutrality
- Write canonical rules in plain Markdown under `docs/ai/`.
- Do not create new canonical rule content under `.claude/`, `.cursor/`, or any other tool-specific directory.
- Tool adapters and slash commands must reference the canonical file instead of restating its rules.

### Document type boundaries
- Put facts in `context.md`.
- Put constraints and modification boundaries in `rules.md`.
- Put phased changes in `plan.md`.
- Put calculations, field mappings, and other supporting notes in `references.md`.

### Quality bar
- Prefer clear headings and short bullet lists over long narrative blocks.
- Use stable names and repository-relative paths.
- Avoid mixing current-state facts with proposed architecture.
- Keep rules enforceable. Replace vague advice with explicit constraints or explicit preferences.

### Update discipline
- When behavior changes, update the relevant feature-local knowledge in the same commit.
- When a cross-cutting rule changes, update the matching foundational rule, and this map if the navigation model changed.
- Remove stale duplicates instead of keeping parallel versions of the same rule.

## Quick Navigation

- Repository map: `docs/ai-playbook.md`
- Neutral knowledge root: `docs/ai/`
- Foundational rules: `docs/ai/foundation/`
- Task workflows: `docs/ai/workflows/`
- Feature-local knowledge: `docs/ai/features/`
- Behavior contract: `docs/ai/foundation/behavior_contract.md`
- Commit command: `.claude/commands/commit.md`
