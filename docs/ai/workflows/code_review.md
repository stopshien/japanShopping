# Code Review Workflow

Use this workflow when reviewing changes in this repository.

## Review Priority
1. correctness and crashes
2. storyboard / code connection mismatches
3. persistence compatibility with existing saved files
4. threading and state issues
5. architecture boundary violations
6. naming and style

## Review Style
- Lead with findings, not summary.
- Prefer concrete, actionable feedback tied to behavior.
- Treat feature-local hard constraints as higher priority than generic style advice.
- Do not demand MVVM, dependency injection, or tests that the repository does not use; review against the rules in `docs/ai/foundation/`.

## Repository-Specific Checks
- Force unwraps: `Double(text)!`, `imageName!`, `date!`, `as! Cell`.
- Array ranges of the form `0...array.count-1`, which trap when the array is empty.
- UIKit updates inside a `URLSession` completion handler without `DispatchQueue.main.async`.
- Strong `self` capture in escaping closures on a screen that can be popped.
- File IO that resolves the Documents directory itself instead of using `List.documentDirectory`.
- Absolute image paths stored on `List.photoURL` instead of a bare filename.
- New hard-coded API keys or credentials.
- Derived UI values (total spend, feedback remaining) that are not recomputed after a mutation.
