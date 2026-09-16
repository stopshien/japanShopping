# Code Review Workflow

Use this workflow when reviewing changes in this repository.

## Review Priority
1. correctness and crashes
2. layer violations (logic in the view, UIKit in the ViewModel, IO outside a service)
3. persistence compatibility with existing saved files
4. threading and memory issues
5. missing tests on new ViewModel logic
6. naming and style

## Review Style
- Lead with findings, not summary.
- Prefer concrete, actionable feedback tied to behavior.
- Treat feature-local hard constraints as higher priority than generic style advice.
- Check `docs/ai/foundation/migration_status.md` before flagging a legacy file. Legacy style in a screen that has not been migrated is not a finding; legacy style in new or migrated code is.

## Repository-Specific Checks
- A ViewModel that imports UIKit, or a controller that computes a business value.
- A service constructed inline instead of injected.
- A subject exposed publicly instead of an `AnyPublisher`.
- A `sink` without `[weak self]`, or a subscription not stored in `cancellables`.
- UI updates without `.receive(on: DispatchQueue.main)`.
- Force unwraps: `Double(text)!`, `imageName!`, `date!`, `as! Cell`.
- Array ranges of the form `0...array.count-1`, which trap when the array is empty.
- File IO that resolves the Documents directory itself.
- Absolute image paths persisted instead of a bare filename; deleted items that leave orphaned image files.
- New hard-coded API keys or credentials.
- Derived UI values not recomputed after a mutation.
- A migration commit that also changes behavior.
