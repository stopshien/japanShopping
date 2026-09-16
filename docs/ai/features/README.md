# Feature-Local Knowledge

Each feature directory is the source of truth for that feature's current knowledge.

## Structure

```text
docs/ai/features/<feature>/
├── context.md
├── rules.md
├── plan.md
└── references.md   # optional
```

- New feature-local AI knowledge must be added here, not under `.claude/` or another tool-specific folder.
- Feature-local rules override generic workflow guidance when they are more specific.
- Do not place feature-specific facts in `docs/ai/foundation/`.

## `context.md`
- describe the current implementation and its purpose
- identify the main files, state owners, and data flow
- document external contracts and key dependencies
- avoid prescribing refactors

## `rules.md`
- document non-negotiable flows, API contracts, and ownership boundaries
- separate hard constraints from softer design preferences
- state what may be changed directly and what requires explicit proposal

## `plan.md`
- describe safe sequencing for future changes
- start with low-risk cleanup and structure work
- call out risky areas that should not be moved casually

## `references.md`
- keep detailed supporting material here
- examples: tax and feedback formulas, field dictionaries, terminology

## Candidate Features

No feature directory exists yet. Create one when work touches a non-trivial area, for example:
- `exchange_rate/` — rate fetch, date conversion, tax calculation
- `credit_card_feedback/` — card creation, feedback calculation, remaining-limit tracking
- `shopping_list/` — list persistence, photo storage, total spend
