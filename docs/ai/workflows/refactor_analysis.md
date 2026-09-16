# Refactor Analysis Workflow

Use this workflow when asked to clean up or restructure code that is not a full screen migration. For converting a legacy screen, use `screen_migration.md` instead.

## Sequence
1. Describe the current behavior before proposing any change.
2. Identify the boundary that is wrong.
3. Propose the smallest sequence of steps that keeps the app runnable after each step.
4. Get agreement before a change that moves files, renames storyboard-connected symbols, or alters a stored model shape.

## Safe First Moves
- Extract a long method into named private helpers within the same type.
- Replace a force unwrap or an unchecked `0...count-1` range with a safe equivalent.
- Move duplicated formatting or persistence logic behind the right boundary.
- Name a magic number.

## Risky Areas — Propose, Do Not Just Do
- Renaming an `@IBOutlet`, `@IBAction`, or storyboard identifier on a legacy screen: breaks the scene at runtime until the storyboard is updated.
- Changing a `Codable` model's stored properties: invalidates users' saved `list` and `cards` files.
- Anything listed under Known Behavior To Preserve in `docs/ai/foundation/migration_status.md`.

## Deliverables
- a short current-state summary
- an ordered change list with the risk of each step
- explicit callouts for anything that needs the storyboard opened
