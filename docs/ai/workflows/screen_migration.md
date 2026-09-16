# Screen Migration Workflow

Use this workflow when converting a legacy Storyboard/MVC screen to programmatic UIKit + MVVM + Combine.

Migrate one screen per commit. Do not migrate two screens at once, and do not change behavior while migrating.

## Sequence

1. **Record the current behavior.** Read the legacy controller and write down every rule it enforces, including the ones that look accidental. Add anything durable to `docs/ai/foundation/migration_status.md` under Known Behavior To Preserve.
2. **Extract the model and service first.** Move persistence off the model type into a protocol-defined repository. The legacy screen can keep calling it during the transition.
3. **Write the ViewModel.** Protocol-defined Input / Output, UIKit-free, services injected. Port the logic verbatim first; fix bugs in a separate follow-up commit so the diff stays reviewable.
4. **Write the view controller.** Programmatic views, `setupViews()` / `setupConstraints()` / `bindViewModel()`, initializer injection.
5. **Rewire navigation.** The caller constructs the next ViewModel and passes it to the next controller's initializer. Remove the property-assignment handoff.
6. **Delete the legacy scene and controller** in the same commit, including the storyboard scene and its segues.
7. **Add tests** for the new ViewModel.
8. **Update `migration_status.md`**: move the screen from legacy to migrated.

## Ordering Across Screens

Migrate in dependency order, leaves first, so each step removes a property-assignment handoff rather than adding one:

1. Card setup and card list (self-contained, smallest surface)
2. Shopping list (consumes persisted items only)
3. Purchase detail (depends on cards and the list)
4. Exchange rate / price entry (entry point, pushes into detail)

Create the unit test target before the first screen, as part of step 1.

## Hard Rules

- Behavior must be identical after the migration unless the task explicitly says otherwise.
- Do not leave a screen half-migrated across commits. Each commit ends with the app building and running.
- Do not keep a legacy and a migrated version of the same screen side by side.
- Removing a storyboard scene requires checking every segue and unwind that referenced it.

## Deliverables

- the new ViewModel, view controller, and any extracted service
- deleted legacy files and storyboard scene
- tests for the new ViewModel
- an updated `migration_status.md`
- a stated verification result: built, run, and which screen was exercised
