# Repository Operating Model

Treat repository-local knowledge as the system of record.

## Core Principles
- Start from the smallest stable entrypoint and progressively load more detail.
- Use `AGENTS.md`, `CLAUDE.md`, and `docs/ai-playbook.md` as maps, not encyclopedias.
- Prefer durable repository artifacts over ad-hoc instructions in chat.
- If a rule matters repeatedly, encode it in the repository.

## Knowledge Loading Order
1. Read the entrypoint files and the playbook.
2. Apply the matching foundational rules.
3. Load workflow guidance only if the task clearly matches that workflow.
4. Load feature-local knowledge when the task touches that feature.

## Documentation Discipline
- Keep facts in `context.md`.
- Keep constraints in `rules.md`.
- Keep staged change guidance in `plan.md`.
- Keep supporting details in `references.md`.
- Update the relevant knowledge artifact when behavior changes.

## Legibility Rules
- Prefer explicit file paths, type names, and named responsibilities.
- Prefer structured markdown over long free-form prose.
- Avoid duplicate rule copies in multiple locations.
- Remove stale knowledge instead of keeping shadow documents.

## Scope Discipline
- This is a small single-target app. Prefer the smallest change that solves the task.
- Do not introduce a framework, architecture pattern, or dependency beyond the target stack in `ios_architecture.md` without explicit approval.
- Read `behavior_contract.md` before changing anything that looks like an oddity. Several deliberate behaviours look like bugs.
