# Refactor Analysis Workflow

Use this workflow when asked to clean up or restructure existing code.

## Sequence
1. Describe the current behavior before proposing any change.
2. Identify the boundary that is wrong.
3. Propose the smallest sequence of steps that keeps the app runnable after each step.
4. Get agreement before a change that moves files or alters a stored model shape.

## Safe First Moves
- Extract a long method into named private helpers within the same type.
- Replace a force unwrap or an unchecked `0...count-1` range with a safe equivalent.
- Move duplicated formatting or persistence logic behind the right boundary.
- Name a magic number.

## Risky Areas — Propose, Do Not Just Do
- Changing a `Codable` model's stored properties: invalidates users' saved `list` and `cards` files.
- Anything listed in `docs/ai/foundation/behavior_contract.md`.

## Deliverables
- a short current-state summary
- an ordered change list with the risk of each step
