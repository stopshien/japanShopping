# Persistence And Networking

All IO lives behind a protocol-defined service. A view controller never performs IO, and a ViewModel never touches `FileManager`, `URLSession`, or `JSONDecoder` directly.

## Service Contracts

- Define a protocol per responsibility, and inject it into the ViewModel.
- Return `AnyPublisher<Output, Error>` for asynchronous work; return a plain value for synchronous local reads.
- Keep the protocol free of UIKit types. Pass `Data` rather than `UIImage` across the boundary where practical.

```swift
protocol ShoppingListRepository {
    func load() throws -> [ShoppingItem]
    func save(_ items: [ShoppingItem]) throws
}

protocol ExchangeRateService {
    func latestRate() -> AnyPublisher<ExchangeRate, Error>
}

protocol ImageStore {
    func save(_ data: Data) throws -> String   // returns the stored filename
    func loadData(named filename: String) throws -> Data
    func remove(named filename: String) throws
}
```

## Persistence Model
- Persistence uses `PropertyListEncoder` / `PropertyListDecoder` writing to the app's Documents directory.
- Exactly one type resolves the Documents directory. Do not call `FileManager.default.urls(for:in:)` anywhere else.
- Models stay as plain `Codable` value types. Do not put `save` / `read` static methods back onto the model.
- Do not migrate to Core Data, SwiftData, or `UserDefaults` for these models without explicit approval.
- Changing a stored model's properties invalidates existing saved files. Give a new property a default value and state the migration impact in the change description.

## Image Storage
- Store photos as JPEG in the Documents directory under a `UUID` filename; persist only the filename on the item.
- Never store an absolute path — the app container path changes between installs.
- Deleting an item must delete its image through `ImageStore.remove(named:)`. Orphaned image files are a defect, not accepted behavior.

## Networking
- Networking uses `URLSession` with `JSONDecoder`, wrapped in a service. There is no third-party HTTP client.
- Exchange rates come from `https://v6.exchangerate-api.com/v6/<key>/latest/USD`, decoded into `ExchangeRate` / `Rates`.
- The service returns a publisher. Threading is the subscriber's concern: the view applies `.receive(on: DispatchQueue.main)`.
- Never touch UIKit from a background context.
- Parse dates with an explicit `Locale(identifier: "en_US_POSIX")` and an explicit `TimeZone`. Never force-unwrap `DateFormatter.date(from:)`.

## Error Handling
- Surface failures as a typed error on the publisher or a thrown error, and let the ViewModel map it to a user-facing message.
- Do not swallow errors with `try?` in new service code. `try?` is acceptable only where a missing file legitimately means "no data yet".
- Never force-unwrap a decode result or a file read.

## Secrets
- The exchange-rate API key is currently hard-coded in the rate-fetching code. Treat this as known debt to resolve during migration: move it out of source into the build configuration or `Info.plist`.
- Do not add new hard-coded keys, tokens, or credentials to source files.
- Do not commit `.env` files, certificates, or provisioning secrets.
