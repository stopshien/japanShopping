# iOS Architecture Baseline

This repository is a single-target UIKit app with the following stack:
- Swift 5
- iOS 16.2 deployment target (`japanShopping.xcodeproj`)
- UIKit, built programmatically
- MVVM with Combine
- No third-party dependencies: no CocoaPods, no Swift Package Manager, no Carthage

## Layer Responsibilities

### View (`UIViewController`, `UIView`)
- Own view lifecycle, view construction, layout, and binding.
- Hold exactly one ViewModel, injected through the initializer.
- Contain no business rules: no currency conversion, no tax arithmetic, no feedback calculation, no persistence.
- Translate user interaction into a ViewModel input, and render ViewModel output. Nothing else.

### ViewModel
- Own all screen logic and screen state.
- Never import UIKit.
- Depend on protocols, never on concrete services.
- Expose an Input / Output pair; do not expose mutable subjects to the view.

### Model
- Plain `Codable` value types with no UIKit import and no persistence logic.
- Persistence and networking belong to services, not to the model. See `docs/ai/foundation/persistence_and_networking.md`.

### Service
- Own IO: file persistence, networking, image storage.
- Defined by a protocol so the ViewModel can be tested against a stub.

## ViewModel Contract

- Use `@Published` or `CurrentValueSubject` for state, exposed as `AnyPublisher`.
- Use `PassthroughSubject` for one-off events such as navigation or alerts.
- Keep every subject `private`; expose only the publisher.
- Name outputs for what they mean: `isLoading`, `items`, `errorMessage`, `route`.
- Model loading, success, and failure explicitly rather than leaving a blank state.
- Store cancellables in a `private var cancellables = Set<AnyCancellable>()` owned by the type that subscribes.
- Use `[weak self]` in every closure that outlives the call.

```swift
protocol ExchangeRateViewModelType {
    var input: ExchangeRateViewModelInput { get }
    var output: ExchangeRateViewModelOutput { get }
}

protocol ExchangeRateViewModelInput {
    func viewDidLoad()
    func yenTextChanged(_ text: String)
    func taxModeChanged(_ mode: TaxMode)
}

protocol ExchangeRateViewModelOutput {
    var convertedPrice: AnyPublisher<PriceBreakdown, Never> { get }
    var rateDescription: AnyPublisher<String, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
}
```

## Dependency Injection
- Inject dependencies through the initializer. Do not resolve them inside the type.
- Depend on a protocol, not a concrete type, for anything that touches IO.
- Provide a default argument only when the concrete type is the obvious production choice and the protocol is still the declared parameter type.
- Do not introduce singletons, global registries, or a service locator.

## Navigation
- A ViewModel does not push, present, or dismiss. It emits a route event; the view or its owner performs the navigation.
- A screen never reaches into another screen's state. Pass data forward through the next ViewModel's initializer, never by assigning properties on an instantiated controller.
- Keep navigation decisions in one place per flow rather than spread across sibling controllers.

## Screen Map
- Exchange rate / price entry — JPY input, tax mode, live rate, produces a priced item
- Purchase detail — product name, pay type, card selection, photo selection
- Shopping list — list display, total spend, row deletion
- Card setup — creates a card
- Card list — lists and deletes cards

## Forbidden Without Explicit Approval
- Adding a third-party dependency or a dependency manager.
- Introducing SwiftUI, RxSwift, or async-await-based rewrites of the Combine layer.
- Introducing Storyboard or XIB. Every screen is built in code.
- Moving IO into a view controller.
