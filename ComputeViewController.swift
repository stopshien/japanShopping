//
//  ComputeViewController.swift
//  japanShopping
//

import Combine
import UIKit

final class ComputeViewController: UIViewController {

    private enum Constants {
        static let fieldHeight: CGFloat = 48
        static let segmentHeight: CGFloat = 36
    }

    private let viewModel: ComputeViewModelType
    private let factory: ScreenFactory
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Views

    private let rateLabel = AppView.label(font: AppStyle.Font.title, alignment: .center)
    private let updatedAtLabel = AppView.label(
        font: AppStyle.Font.caption, color: AppColor.textSecondary, alignment: .center
    )

    private let inputCard = AppView.card()
    private let resultCard = AppView.card()

    private let taxCategorySegmentedControl = AppView.segmentedControl(items: [])
    private let taxSegmentedControl = AppView.segmentedControl(items: TaxMode.allCases.map(\.title))
    private let amountTextField = AppView.textField(keyboardType: .decimalPad)

    private let computeButton = AppView.primaryButton(title: "換算")
    private let useUntaxedButton = AppView.secondaryButton(title: "使用未稅價格")
    private let useTaxedButton = AppView.secondaryButton(title: "使用含稅價格")

    private let resultTitleLabel = AppView.label(
        "換算結果", font: AppStyle.Font.label, color: AppColor.textSecondary, alignment: .center
    )
    private let resultLabel = AppView.label(
        "—", font: AppStyle.Font.resultNumber, alignment: .center
    )

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

    // MARK: - Setup

    private func setupViews() {
        title = "匯率換算"
        view.backgroundColor = AppColor.brand
        navigationItem.leftBarButtonItem = AppView.barButton(
            systemImage: "gearshape",
            accessibilityLabel: "設定",
            target: self,
            action: #selector(settingsTapped)
        )
        navigationItem.rightBarButtonItem = AppView.barButton(
            systemImage: "cart",
            accessibilityLabel: "查看購物清單",
            target: self,
            action: #selector(showShoppingListTapped)
        )
        addTapToDismissKeyboard()

        // 輸入卡：幣別、稅率類別、金額、未稅／含稅
        let inputStack = AppView.cardStack(in: inputCard, spacing: AppStyle.Spacing.tight + 4)
        [
            taxCategorySegmentedControl,
            amountTextField,
            taxSegmentedControl,
            computeButton
        ].forEach(inputStack.addArrangedSubview)
        inputStack.setCustomSpacing(AppStyle.Spacing.normal, after: taxSegmentedControl)

        // 結果卡：標題 + 數字 + 兩顆帶價前往的按鈕
        let resultStack = AppView.cardStack(in: resultCard, spacing: AppStyle.Spacing.tight)
        [resultTitleLabel, resultLabel, useUntaxedButton, useTaxedButton].forEach(resultStack.addArrangedSubview)
        resultStack.setCustomSpacing(AppStyle.Spacing.normal, after: resultLabel)

        [rateLabel, inputCard, resultCard].forEach(contentStackView.addArrangedSubview)
        contentStackView.setCustomSpacing(AppStyle.Spacing.loose, after: rateLabel)

        view.addSubview(contentStackView)
        view.addSubview(updatedAtLabel)

        taxCategorySegmentedControl.addTarget(self, action: #selector(taxCategoryChanged), for: .valueChanged)
        taxSegmentedControl.addTarget(self, action: #selector(taxModeChanged), for: .valueChanged)
        amountTextField.addTarget(self, action: #selector(amountTextChanged), for: .editingChanged)
        computeButton.addTarget(self, action: #selector(computeTapped), for: .touchUpInside)
        useUntaxedButton.addTarget(self, action: #selector(useUntaxedTapped), for: .touchUpInside)
        useTaxedButton.addTarget(self, action: #selector(useTaxedTapped), for: .touchUpInside)

        taxSegmentedControl.selectedSegmentIndex = TaxMode.excludingTax.rawValue
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppStyle.Spacing.loose
            ),
            contentStackView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: AppStyle.Spacing.normal
            ),
            contentStackView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -AppStyle.Spacing.normal
            ),

            amountTextField.heightAnchor.constraint(equalToConstant: Constants.fieldHeight),
            taxCategorySegmentedControl.heightAnchor.constraint(equalToConstant: Constants.segmentHeight),
            taxSegmentedControl.heightAnchor.constraint(equalToConstant: Constants.segmentHeight),

            updatedAtLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: AppStyle.Spacing.normal
            ),
            updatedAtLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -AppStyle.Spacing.normal
            ),
            updatedAtLabel.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppStyle.Spacing.tight
            )
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.rateDescription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.rateLabel.text = text
            }
            .store(in: &cancellables)

        viewModel.output.inputPlaceholder
            .receive(on: DispatchQueue.main)
            .sink { [weak self] placeholder in
                self?.amountTextField.placeholder = placeholder
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

        viewModel.output.updatedAtDescription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.updatedAtLabel.text = text
            }
            .store(in: &cancellables)

        viewModel.output.resultText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.renderResult(text)
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
            navigationController?.pushViewController(factory.makeDetail(item: item), animated: true)
        case .shoppingList:
            navigationController?.pushViewController(factory.makeShoppingList(), animated: true)

        case .settings:
            let controller = factory.makeSettings { [weak self] in
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

    @objc private func taxModeChanged() {
        guard let mode = TaxMode(rawValue: taxSegmentedControl.selectedSegmentIndex) else { return }
        viewModel.input.taxModeChanged(to: mode)
    }

    @objc private func amountTextChanged() {
        viewModel.input.amountTextChanged(amountTextField.text ?? "")
    }

    @objc private func computeTapped() {
        amountTextField.resignFirstResponder()
        viewModel.input.computeTapped()
    }

    @objc private func useUntaxedTapped() {
        viewModel.input.usePrice(for: .excludingTax)
    }

    @objc private func useTaxedTapped() {
        viewModel.input.usePrice(for: .includingTax)
    }

    @objc private func showShoppingListTapped() {
        viewModel.input.showShoppingListTapped()
    }

    @objc private func settingsTapped() {
        viewModel.input.settingsTapped()
    }

    // MARK: - Private

    /// ViewModel 送出的是「台幣 \n未稅：X\n含稅：Y」，
    /// 這裡只負責把它排成兩行等寬數字，不改內容。
    private func renderResult(_ text: String) {
        let hasResult = text.contains("\n")
        resultLabel.text = hasResult
            ? text.split(separator: "\n").dropFirst().joined(separator: "\n")
            : "—"
        resultTitleLabel.text = hasResult ? "換算結果（台幣）" : "換算結果"
        useUntaxedButton.isEnabled = hasResult
        useTaxedButton.isEnabled = hasResult
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
