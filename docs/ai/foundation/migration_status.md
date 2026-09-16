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

Migrated screens: none yet.

Legacy, not yet migrated:
- `ComputeViewController` — rate fetch, tax arithmetic, and navigation all inline
- `DetailViewController` — holds `lists`, `cards`, `numberOfCards`; owns feedback calculation and image writing
- `ListViewController` — owns total-spend calculation and save timing
- `CardSetViewController` — builds a `Card` directly from text fields
- `EditCardsTableViewController` — mutates a copy of `cards` handed to it by its parent

Legacy infrastructure:
- `Main.storyboard` holds every scene
- `List` and `Card` carry their own static save/read methods
- No test target exists
- The exchange-rate API key is hard-coded in source

## Known Behavior To Preserve

Carry these forward deliberately during migration; do not drop them by accident.

- `ListViewController` deliberately saves only when the user taps Done, so a mis-tapped deletion can be abandoned.
- The card feedback calculation subtracts 1.5 from the card percentage before applying it.
- Tax conversion uses a 1.08 multiplier, applied in both directions depending on the selected segment.
- `DetailViewController` currently decides pay type by checking whether the card button is hidden, because comparing `payType` against the string `"信用卡"` did not work. Find the real cause during migration rather than reproducing the workaround.

## Update Discipline
- Move a screen from the legacy list to the migrated list in the same commit that migrates it.
- Delete a "known behavior" entry only when the behavior is intentionally removed, and say so in the commit message.
- When the last screen is migrated, replace this file with a short note and remove the legacy carve-outs from the foundation rules.
