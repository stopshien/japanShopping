# Refactor Analysis Workflow

Use this workflow when asked to clean up, restructure, or analyze existing code.

## Sequence
1. Describe the current behavior before proposing any change.
2. Identify the boundary that is wrong (controller holding model logic, duplicated persistence, an oversized method).
3. Propose the smallest sequence of steps that keeps the app runnable after each step.
4. Get agreement before a change that moves files, renames storyboard-connected symbols, or alters a stored model shape.

## Safe First Moves
- Extract a long method into named private helpers within the same type.
- Replace a force unwrap or an unchecked `0...count-1` range with a safe equivalent.
- Move duplicated persistence or formatting logic onto the model type.
- Name a magic number.

## Risky Areas — Propose, Do Not Just Do
- Renaming an `@IBOutlet`, `@IBAction`, or storyboard identifier: breaks the scene at runtime until the storyboard is updated.
- Changing a `Codable` model's stored properties: invalidates users' saved `list` and `cards` files.
- The unwind-segue contract on `DetailViewController`.
- The deliberate "save only on Done" behavior in `ListViewController`.
- The card feedback calculation in `DetailViewController.cardChooseButtonSet()`, including the `- 1.5` adjustment.

## Deliverables
- a short current-state summary
- an ordered change list with the risk of each step
- explicit callouts for anything that needs the storyboard opened
