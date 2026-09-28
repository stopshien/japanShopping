# Credit Card Feedback — Rules

## Hard Constraints

- **Existing saved cards must still load.** The `cards` file is a property list keyed by property names. Never rename or remove a stored property; every new property is optional. `PersistenceFormatTests`, `FileCardRepositoryTests`.
- **Feedback is recorded only after the purchase is saved.** An empty name or a failed shopping-list save never records feedback, and retrying never records it twice. `DetailViewModelTests`.
- **Money is rounded to cents at every stored step.** Unrounded floating point values accumulate across purchases.
- **The app never infers conditions it cannot see.** Whether a purchase qualifies for a bonus (designated store, contactless, registration) and which switchable plan is active are user inputs.
- **A saved purchase keeps the plan and amounts it was saved with.** Editing a card or plan later, or a plan expiring, never recalculates past purchases.
- **Caps apply to the gross bonus**, before the foreign transaction fee, because that is how banks count them.
- **Remaining amounts are estimates.** Banks assign purchases to periods by posting date, which the app cannot know. UI wording must not promise an exact figure near period boundaries.
- **Cards stay shared across trips.** A card's usage in a period includes purchases from every trip.
- **No bank data is fetched.** Banks publish no API, and campaigns change every few months. The user enters and updates plans by hand.

## Soft Preferences

- Keep a card with one plan and no bonus as simple to enter as today's card (name, rate, and optionally a cap).
- Prefer computing remaining amounts from recorded entries over storing a running balance.
- Put period arithmetic (calendar month, statement cycle, quarter, campaign) in one pure, testable type with an injected `Calendar`.

## Changes That Need An Explicit Proposal

- Changing the fee subtracted from the rate, or making it per card.
- Changing what 「這筆回饋」 displays. Decided: gross amount with the fee listed separately.
- Removing the legacy fields from `Card`.
- Any change to the behavior contract entries about card feedback in `docs/ai/foundation/behavior_contract.md`.
