# New Feature Development Workflow

Use this workflow when building a new screen or adding a substantial new capability.

## Starting Sequence
1. Read `docs/ai-playbook.md` and the applicable foundational rules.
2. Check whether the target area already has feature-local knowledge under `docs/ai/features/<feature>/`.
3. If no feature-local knowledge exists and the change is non-trivial, create `context.md`, `rules.md`, and `plan.md` before expanding implementation scope.

## Implementation Expectations
- Follow the repository stack: Swift, UIKit, Storyboard, MVC, no third-party dependencies.
- A new screen means a new storyboard scene plus a `UIViewController` subclass in its own file; set the storyboard ID to the type name.
- Pass data to the next screen by assigning its properties before the push, matching the existing pattern.
- Persist new model data through a `Codable` model type with its own save/read methods, as `List` and `Card` do.
- Keep networking on `URLSession` with `JSONDecoder`, and update UI on the main queue.

## Deliverables
- compilable, runnable code
- storyboard connections that match the code
- updated feature-local knowledge when the behavior is durable
- a stated verification result: what was built, what was run, what was not checked

## Review Checklist
- Are responsibilities separated between the controller and the model?
- Does any new stored property break existing saved `list` / `cards` files?
- Are new outlets and actions connected, and are old connections still valid?
- Are there force unwraps or unchecked array ranges on the new path?
- Is there feature-specific knowledge that should be written down for future agent runs?
