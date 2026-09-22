# UI And Layout Conventions

## UI Construction
- Build UI programmatically. There is no Storyboard in this project; do not add one.
- Use `NSLayoutConstraint` anchors with `translatesAutoresizingMaskIntoConstraints = false`. Do not add SnapKit or any other layout library.
- Declare views as `private let` properties initialized inline or by a factory method.

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
  - Exception: text written back into the field the user is typing in (for example thousands separators) is applied synchronously. The input event already runs on the main thread, and an asynchronous write-back lands after the next keystroke and overwrites it.
- Use `[weak self]` in every `sink`.
- Store subscriptions in the controller's own `cancellables`.
- Render output; do not recompute it. If the view needs a formatted string, the ViewModel supplies the formatted string.

## Table Views
- Register cells by type and dequeue with a typed helper; do not force-cast with `as!`.
- Give the cell a `configure(with:)` method that takes a display model. The data source must not reach into files or services.
- Derived values such as total spend come from the ViewModel, recomputed on every mutation.

## Design System

- **The palette is light-only and the window is pinned to `.light`.** `AppColor` has no dark variants, so any colour left to the system would flip on its own and clash with the hardcoded light surfaces. If dark mode is ever wanted, every colour needs a dark counterpart first, then the override comes off.
- **Never leave a colour to the system.** Placeholder text was the one that slipped through: its system colour dropped to a contrast of 1.05 on our white fields in dark mode. Use `AppTextField`, which pins `AppColor.placeholder`.
- `AppColor` is the only place colours are defined. Every foreground/background pair in it passes WCAG AA (contrast ≥ 4.5); this app is used outdoors, so low contrast is a defect, not a style choice. Verify the ratio before changing any colour.
- `AppStyle` owns spacing (8pt scale), corner radii and fonts. Do not write raw numbers for these in a view controller.
- **Every font in `AppStyle.Font` scales with the system text size** (`UIFontMetrics`), and money fonts carry a maximum point size so a large amount still fits on one line. Views built by `AppView` set `adjustsFontForContentSizeCategory`, so a text-size change applies without relaunching.
- Give controls a **minimum** height (`greaterThanOrEqualToConstant`), never a fixed one: at accessibility text sizes a fixed height clips the text. Table rows use `automaticDimension`.
- A text field's `leftView`/`rightView` is sized from its own `frame`, not from constraints, so recompute that frame whenever the font or the text changes. Sizing it once at setup leaves the old width behind after a text-size change and squeezes out the symbol and the placeholder.
- A label-and-field or label-and-button row placed side by side must switch to a vertical stack at accessibility text sizes; otherwise one side is squeezed to a few characters. The project supports iOS 15, so watch for the change in `traitCollectionDidChange`, not iOS 17's `registerForTraitChanges`.
- `AppView` builds the shared components: `primaryButton`, `secondaryButton`, `plainButton`, `card`, `cardStack`, `label`, `textField`, `segmentedControl`.
- Use `PhotoButton` for any tap-to-pick photo area. Never `setImage` a photo onto a system `UIButton`: it renders the image as a template and the photo becomes a solid tint-coloured block.
- **One primary button per screen.** It is the action the screen exists for. Everything else is secondary or plain.
- Secondary buttons use a tinted background, never white — they usually sit on a white card, where a white fill makes them look like plain text.
- Group related controls into a `card`. A screen should read as a few blocks, not a flat list of controls.
- `AppAppearance` configures the navigation bar once, from `SceneDelegate`.
- Navigation that is available but not the point of the screen belongs in the navigation bar, via `AppView.barButton`, not in the content stack. Every bar button needs an `accessibilityLabel` — VoiceOver otherwise reads the SF Symbol name.

## Text And Formatting
- User-facing strings are Traditional Chinese.
- User-facing terms: a `Trip` is **旅程** and the shopping list is **消費紀錄**. Do not show 專案 or 購物清單 to the user; the type names in code stay as they are.
- Formatting belongs in the ViewModel, not the view. Never interpolate a raw `Double` into a user-facing label.
- Avoid magic numbers. Put spacing, sizes, tax rates, and limits in a private `enum Constants` next to the type that uses them.

## Keyboard
- Dismiss the keyboard with a `UITapGestureRecognizer` targeting `UIView.endEditing(_:)`. Extract this into a shared helper rather than repeating it in every controller.
