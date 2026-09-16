# UI And Layout Conventions

## UI Construction
- Build UI programmatically. Do not add new Storyboard or XIB scenes.
- Use `NSLayoutConstraint` anchors with `translatesAutoresizingMaskIntoConstraints = false`. Do not add SnapKit or any other layout library.
- Declare views as `private let` properties initialized inline or by a factory method.
- `Main.storyboard` remains only for screens that have not been migrated yet; see `docs/ai/foundation/migration_status.md`.

## Screen Structure
- Organize every view controller as `setupViews()`, `setupConstraints()`, and `bindViewModel()`, called in that order from `viewDidLoad()`.
- Keep `viewDidLoad()` to those three calls plus an input notification to the ViewModel.
- Put `UITableViewDataSource`, `UIPickerViewDelegate`, `UIImagePickerControllerDelegate`, and similar conformances in separate extensions, one responsibility per extension.
- Use `// MARK: -` to separate properties, lifecycle, setup, binding, actions, and protocol conformances.

```swift
final class ShoppingListViewController: UIViewController {
    private let viewModel: ShoppingListViewModelType
    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView()
    private let totalSpendLabel = UILabel()

    init(viewModel: ShoppingListViewModelType) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        bindViewModel()
        viewModel.input.viewDidLoad()
    }

    // MARK: - Setup

    private func setupViews() { }

    private func setupConstraints() { }

    // MARK: - Binding

    private func bindViewModel() { }
}
```

## Binding
- Bind in `bindViewModel()` only. Do not subscribe from `setupViews()` or from an action handler.
- Receive on the main queue explicitly: `.receive(on: DispatchQueue.main)`.
- Use `[weak self]` in every `sink`.
- Store subscriptions in the controller's own `cancellables`.
- Render output; do not recompute it. If the view needs a formatted string, the ViewModel supplies the formatted string.

## Table Views
- Register cells by type and dequeue with a typed helper; do not force-cast with `as!`.
- Give the cell a `configure(with:)` method that takes a display model. The data source must not reach into files or services.
- Derived values such as total spend come from the ViewModel, recomputed on every mutation.

## Text And Formatting
- User-facing strings are Traditional Chinese.
- Formatting belongs in the ViewModel, not the view. Never interpolate a raw `Double` into a user-facing label.
- Avoid magic numbers. Put spacing, sizes, tax rates, and limits in a private `enum Constants` next to the type that uses them.

## Keyboard
- Dismiss the keyboard with a `UITapGestureRecognizer` targeting `UIView.endEditing(_:)`. Extract this into a shared helper rather than repeating it in every controller.
