# New Feature Development Workflow

Use this workflow when building a new screen or adding a substantial new capability.

## Starting Sequence
1. Read `docs/ai-playbook.md` and the applicable foundational rules.
2. Read `docs/ai/foundation/behavior_contract.md` if the feature touches anything it records.
3. Check whether the target area has feature-local knowledge under `docs/ai/features/<feature>/`.
4. If no feature-local knowledge exists and the change is non-trivial, create `context.md`, `rules.md`, and `plan.md` before expanding implementation scope.

## Implementation Expectations
- Follow the stack: Swift, UIKit built programmatically, MVVM, Combine, no third-party dependencies.
- A new screen is at minimum three files: the ViewModel protocols, the ViewModel, and the view controller.
- Put every business rule in the ViewModel. The controller only binds and renders.
- Put every IO operation behind a service protocol and inject it.
- Add new screens to `ScreenFactory` rather than constructing services at the call site.
- Give the ViewModel a test alongside it.

## Deliverables
- compilable, runnable code
- unit tests for new ViewModel logic
- updated feature-local knowledge when the behavior is durable
- a stated verification result: what was built, what was run, what was not checked

## Review Checklist
- Does the ViewModel import UIKit? It must not.
- Are services injected as protocols, or constructed inline?
- Does any new stored property break existing saved files?
- Are there force unwraps, unchecked array ranges, or strong `self` captures on the new path?
- Is every subscription stored in a `cancellables` set owned by the subscriber?
- Is formatting done in the ViewModel rather than the view?
