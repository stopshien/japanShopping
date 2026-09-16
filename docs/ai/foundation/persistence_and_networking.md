# Persistence And Networking

## Persistence Model
- Persistence uses `PropertyListEncoder` / `PropertyListDecoder` writing to the app's Documents directory.
- Canonical files: `List.saveList(list:)` / `List.readList()` write `list`; `Card.saveCards(cards:)` / `Card.readCards()` write `cards`.
- Keep `List.documentDirectory` as the single place that resolves the Documents URL. Do not call `FileManager.default.urls(for:in:)` again in a view controller.
- Do not migrate to Core Data, SwiftData, or `UserDefaults` for these models without explicit approval.
- Any change to a stored model's properties breaks existing saved files. When adding a property, give it a default value and describe the migration impact in the change description.

## Image Storage
- Selected photos are written as JPEG into the Documents directory under a `UUID` filename; only the filename is stored on `List.photoURL`.
- Store the bare filename, never an absolute path — the app container path changes between installs.
- Rebuild the URL on read with `appendingPathComponent(name).appendingPathExtension("jpg")`.
- When a list item is removed, its image file becomes orphaned. Treat orphan cleanup as a known gap; do not silently change the deletion contract while fixing something else.

## Error Handling For IO
- `try?` is the current repository style for these reads and writes. When adding new IO, prefer surfacing a failure the user can act on over silently swallowing it.
- Never force-unwrap a decode result or a file read.

## Networking
- Networking uses `URLSession.shared.dataTask` with `JSONDecoder`; there is no networking layer or third-party client.
- Exchange rates come from `https://v6.exchangerate-api.com/v6/<key>/latest/USD`, decoded into `ExchangeRate` / `Rates`.
- Update UI only inside `DispatchQueue.main.async`. Never touch UIKit from the completion handler's background context.
- Capture `self` deliberately in completion handlers; prefer `[weak self]` for new closures that outlive a screen.
- Handle the failure path. A decode or transport error must leave the UI in a stated state, not blank.
- Parse dates with an explicit `Locale(identifier: "en_US_POSIX")` and an explicit `TimeZone`, as the existing code does. Never force-unwrap `DateFormatter.date(from:)`.

## Secrets
- The exchange-rate API key is currently hard-coded in `ComputeViewController.swift`. Treat this as known debt.
- Do not add new hard-coded keys, tokens, or credentials to source files.
- Do not commit `.env` files, certificates, or provisioning secrets.
