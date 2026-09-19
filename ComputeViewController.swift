//
//  ComputeViewController.swift
//  japanShopping
//

import Combine
import UIKit

/// 首頁：輸入外幣價格，即時看到台幣金額，再選一般或免稅購買記一筆。
final class ComputeViewController: UIViewController {

    private enum Constants {
        static let amountFieldHeight: CGFloat = 64
        static let segmentHeight: CGFloat = 36
        static let symbolWidth: CGFloat = 44
        static let priceTagWidth: CGFloat = 72
        static let tripChevronSize: CGFloat = 11
        static let tripChevronPadding: CGFloat = 6
    }

    private let viewModel: ComputeViewModelType
    private let factory: ScreenFactory
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Views

    /// 導覽列中間的旅程標籤，點了切換旅程。
    private let tripButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = AppColor.accentSoft
        configuration.baseForegroundColor = AppColor.textPrimary
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(
            systemName: "chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Constants.tripChevronSize, weight: .semibold)
        )
        configuration.imagePlacement = .trailing
        configuration.imagePadding = Constants.tripChevronPadding
        configuration.titleLineBreakMode = .byTruncatingTail
        let button = UIButton(configuration: configuration)
        button.accessibilityHint = "切換旅程"
        return button
    }()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let rateLabel = AppView.label(
        font: AppStyle.Font.caption, color: AppColor.textSecondary, alignment: .center
    )

    private let inputCard = AppView.card()
    private let resultCard = AppView.card()

    private let taxCategorySegmentedControl = AppView.segmentedControl(items: [])

    /// 輸入框右側的「含稅價／未稅價」標註。
    private let priceTagLabel = AppView.label(font: AppStyle.Font.label, alignment: .center)

    private let taxExcludedTitleLabel = AppView.label(
        "標價未含稅（税抜）", font: AppStyle.Font.body, color: AppColor.textPrimary
    )

    private let taxExcludedSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = AppColor.accent
        toggle.accessibilityLabel = "標價未含稅"
        return toggle
    }()

    private lazy var taxExcludedRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [taxExcludedTitleLabel, taxExcludedSwitch])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = AppStyle.Spacing.normal
        return row
    }()

    private let amountTextField: UITextField = {
        let textField = AppView.textField(keyboardType: .decimalPad)
        textField.font = AppStyle.Font.amountInput
        textField.leftViewMode = .always
        // 幣別符號已在左邊，提示只需要一個淡色的 0。
        textField.placeholder = "0"
        return textField
    }()

    private let currencySymbolLabel = AppView.label(
        font: AppStyle.Font.amountInput, color: AppColor.textSecondary, alignment: .center
    )

    private let resultTitleLabel = AppView.label(
        "台幣", font: AppStyle.Font.label, color: AppColor.textSecondary, alignment: .center
    )
    private let primaryAmountLabel = AppView.label(font: AppStyle.Font.resultNumber, alignment: .center)
    private let secondaryAmountLabel = AppView.label(
        font: AppStyle.Font.body, color: AppColor.textSecondary, alignment: .center
    )

    private let regularPurchaseButton = AppView.primaryButton(title: "一般購買")
    private let taxFreePurchaseButton = AppView.secondaryButton(title: "免稅購買")

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = AppStyle.Spacing.normal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Init

    init(viewModel: ComputeViewModelType, factory: ScreenFactory) {
        self.viewModel = viewModel
        self.factory = factory
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        bindViewModel()
        viewModel.input.viewDidLoad()
    }

    /// 還沒輸入價格時直接叫出鍵盤，進來就能打，省一次點擊。
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if amountTextField.text?.isEmpty ?? true {
            amountTextField.becomeFirstResponder()
        }
    }

    // MARK: - Setup

    private func setupViews() {
        view.backgroundColor = AppColor.brand
        navigationItem.titleView = tripButton
        // rightBarButtonItems 由右往左排，設定放在最右邊。
        navigationItem.rightBarButtonItems = [
            AppView.barButton(
                systemImage: "gearshape",
                accessibilityLabel: "設定",
                target: self,
                action: #selector(settingsTapped)
            ),
            AppView.barButton(
                systemImage: "cart",
                accessibilityLabel: "查看消費紀錄",
                target: self,
                action: #selector(showShoppingListTapped)
            )
        ]
        addTapToDismissKeyboard()

        let symbolContainer = UIView(
            frame: CGRect(x: 0, y: 0, width: Constants.symbolWidth, height: Constants.amountFieldHeight)
        )
        currencySymbolLabel.translatesAutoresizingMaskIntoConstraints = true
        currencySymbolLabel.frame = symbolContainer.bounds
        currencySymbolLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        symbolContainer.addSubview(currencySymbolLabel)
        amountTextField.leftView = symbolContainer

        let priceTagContainer = UIView(
            frame: CGRect(x: 0, y: 0, width: Constants.priceTagWidth, height: Constants.amountFieldHeight)
        )
        priceTagLabel.translatesAutoresizingMaskIntoConstraints = true
        priceTagLabel.frame = priceTagContainer.bounds
        priceTagLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        priceTagContainer.addSubview(priceTagLabel)
        amountTextField.rightView = priceTagContainer
        amountTextField.rightViewMode = .always

        // 輸入卡：稅率類別（僅雙稅率國家）、金額、標價未含稅開關（僅常見未稅標價的國家）
        let inputStack = AppView.cardStack(in: inputCard, spacing: AppStyle.Spacing.tight + 4)
        [
            taxCategorySegmentedControl,
            amountTextField,
            taxExcludedRow
        ].forEach(inputStack.addArrangedSubview)

        // 結果卡：台幣大字、未稅補充、兩種購買方式
        let resultStack = AppView.cardStack(in: resultCard, spacing: AppStyle.Spacing.tight)
        [
            resultTitleLabel,
            primaryAmountLabel,
            secondaryAmountLabel,
            regularPurchaseButton,
            taxFreePurchaseButton
        ].forEach(resultStack.addArrangedSubview)
        resultStack.setCustomSpacing(AppStyle.Spacing.loose, after: secondaryAmountLabel)

        [rateLabel, inputCard, resultCard].forEach(contentStackView.addArrangedSubview)
        contentStackView.setCustomSpacing(AppStyle.Spacing.tight + 4, after: rateLabel)

        scrollView.addSubview(contentStackView)
        view.addSubview(scrollView)

        tripButton.addTarget(self, action: #selector(tripListTapped), for: .touchUpInside)
        taxCategorySegmentedControl.addTarget(self, action: #selector(taxCategoryChanged), for: .valueChanged)
        taxExcludedSwitch.addTarget(self, action: #selector(taxExcludedChanged), for: .valueChanged)
        amountTextField.addTarget(self, action: #selector(amountTextChanged), for: .editingChanged)
        regularPurchaseButton.addTarget(self, action: #selector(regularPurchaseTapped), for: .touchUpInside)
        taxFreePurchaseButton.addTarget(self, action: #selector(taxFreePurchaseTapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        let content = scrollView.contentLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // 鍵盤出現時可視範圍縮到鍵盤上緣，被擋住的按鈕可以捲出來。
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            contentStackView.topAnchor.constraint(equalTo: content.topAnchor, constant: AppStyle.Spacing.normal),
            contentStackView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -AppStyle.Spacing.normal),
            contentStackView.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: AppStyle.Spacing.normal
            ),
            contentStackView.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -AppStyle.Spacing.normal
            ),

            amountTextField.heightAnchor.constraint(equalToConstant: Constants.amountFieldHeight),
            taxCategorySegmentedControl.heightAnchor.constraint(equalToConstant: Constants.segmentHeight)
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.tripTitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                self?.tripButton.configuration?.title = title
                self?.tripButton.sizeToFit()
            }
            .store(in: &cancellables)

        viewModel.output.rateDescription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.rateLabel.text = text
            }
            .store(in: &cancellables)

        viewModel.output.currencySymbol
            .receive(on: DispatchQueue.main)
            .sink { [weak self] symbol in
                self?.currencySymbolLabel.text = symbol
            }
            .store(in: &cancellables)

        viewModel.output.amountFieldLabel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] label in
                self?.amountTextField.accessibilityLabel = label
            }
            .store(in: &cancellables)

        viewModel.output.taxCategoryTitles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] titles in
                self?.rebuildTaxCategorySegments(with: titles)
            }
            .store(in: &cancellables)

        viewModel.output.isTaxCategoryVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isVisible in
                self?.taxCategorySegmentedControl.isHidden = !isVisible
            }
            .store(in: &cancellables)

        viewModel.output.priceTagLabel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.priceTagLabel.text = text
            }
            .store(in: &cancellables)

        // 未稅時標註改用強調色，不看開關也知道現在不是預設的含稅。
        viewModel.output.isTaxExcluded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isTaxExcluded in
                self?.taxExcludedSwitch.setOn(isTaxExcluded, animated: true)
                self?.priceTagLabel.textColor = isTaxExcluded ? AppColor.accent : AppColor.textSecondary
                self?.priceTagLabel.font = isTaxExcluded ? AppStyle.Font.bodyEmphasis : AppStyle.Font.label
            }
            .store(in: &cancellables)

        viewModel.output.isTaxExcludedToggleVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isVisible in
                self?.taxExcludedRow.isHidden = !isVisible
            }
            .store(in: &cancellables)

        viewModel.output.result
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.render(result)
            }
            .store(in: &cancellables)

        // 刻意不加 receive(on:)：這裡由輸入事件同步觸發，本來就在主執行緒。
        // 非同步回寫的話，連續快速輸入時晚到的舊文字會蓋掉剛打的數字。
        viewModel.output.amountFieldText
            .sink { [weak self] text in
                self?.amountTextField.text = text
            }
            .store(in: &cancellables)

        viewModel.output.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.presentError(message)
            }
            .store(in: &cancellables)

        viewModel.output.route
            .receive(on: DispatchQueue.main)
            .sink { [weak self] route in
                self?.navigate(to: route)
            }
            .store(in: &cancellables)
    }

    // MARK: - Navigation

    private func navigate(to route: ComputeRoute) {
        switch route {
        case .detail(let item):
            let controller = factory.makeDetail(item: item) { [weak self] in
                self?.viewModel.input.itemSaved()
            }
            navigationController?.pushViewController(controller, animated: true)

        case .shoppingList:
            navigationController?.pushViewController(factory.makeShoppingList(allowsBack: true), animated: true)

        case .settings:
            navigationController?.pushViewController(factory.makeSettings(), animated: true)

        case .tripList:
            let controller = factory.makeTripList { [weak self] in
                self?.viewModel.input.reloadSettings()
            }
            navigationController?.pushViewController(controller, animated: true)
        }
    }

    // MARK: - Actions

    @objc private func taxCategoryChanged() {
        guard let category = TaxCategory(rawValue: taxCategorySegmentedControl.selectedSegmentIndex) else { return }
        viewModel.input.taxCategoryChanged(to: category)
    }

    @objc private func taxExcludedChanged() {
        viewModel.input.taxModeChanged(to: taxExcludedSwitch.isOn ? .excludingTax : .includingTax)
    }

    @objc private func amountTextChanged() {
        viewModel.input.amountTextChanged(amountTextField.text ?? "")
    }

    /// 一般購買付的是含稅價。
    @objc private func regularPurchaseTapped() {
        viewModel.input.usePrice(for: .includingTax)
    }

    /// 免稅購買付的是未稅價。
    @objc private func taxFreePurchaseTapped() {
        viewModel.input.usePrice(for: .excludingTax)
    }

    @objc private func showShoppingListTapped() {
        viewModel.input.showShoppingListTapped()
    }

    @objc private func settingsTapped() {
        viewModel.input.settingsTapped()
    }

    @objc private func tripListTapped() {
        viewModel.input.tripListTapped()
    }

    // MARK: - Private

    private func render(_ result: ComputeResultDisplay) {
        primaryAmountLabel.text = result.primaryAmount
        secondaryAmountLabel.text = result.secondaryDescription
        secondaryAmountLabel.isHidden = result.secondaryDescription.isEmpty
        regularPurchaseButton.setTitle(result.regularPurchaseTitle, for: .normal)
        taxFreePurchaseButton.setTitle(result.taxFreePurchaseTitle, for: .normal)
        regularPurchaseButton.isEnabled = result.isActionable
        taxFreePurchaseButton.isEnabled = result.isActionable
    }

    private func rebuildTaxCategorySegments(with titles: [String]) {
        let previousSelection = taxCategorySegmentedControl.selectedSegmentIndex
        taxCategorySegmentedControl.removeAllSegments()
        for (index, title) in titles.enumerated() {
            taxCategorySegmentedControl.insertSegment(withTitle: title, at: index, animated: false)
        }
        taxCategorySegmentedControl.selectedSegmentIndex =
            titles.indices.contains(previousSelection) ? previousSelection : TaxCategory.standard.rawValue
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}
