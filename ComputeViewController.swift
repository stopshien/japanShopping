//
//  ComputeViewController.swift
//  japanShopping
//

import Combine
import UIKit

final class ComputeViewController: UIViewController {

    private enum Constants {
        static let horizontalInset: CGFloat = 24
        static let spacing: CGFloat = 20
        static let fieldHeight: CGFloat = 44
        static let titleFontSize: CGFloat = 28
        static let resultFontSize: CGFloat = 24
    }

    private let viewModel: ComputeViewModelType
    private let factory: ScreenFactory
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Views

    private let rateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Constants.titleFontSize)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let amountTextField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.backgroundColor = .white
        textField.keyboardType = .decimalPad
        textField.font = .systemFont(ofSize: 20)
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        textField.leftViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let currencySegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: Currency.allCases.map(\.title))
        control.selectedSegmentIndex = Currency.japaneseYen.rawValue
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private let taxCategorySegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private let taxSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: TaxMode.allCases.map(\.title))
        control.selectedSegmentIndex = TaxMode.excludingTax.rawValue
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private let computeButton = ComputeViewController.makeButton(title: "換算")
    private let useUntaxedButton = ComputeViewController.makeButton(title: "使用未稅價格")
    private let useTaxedButton = ComputeViewController.makeButton(title: "使用含稅價格")
    private let showShoppingListButton = ComputeViewController.makeButton(title: "確認清單")

    private let resultLabel: UILabel = {
        let label = UILabel()
        label.text = "換算結果"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .boldSystemFont(ofSize: Constants.resultFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let updatedAtLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = Constants.spacing
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
        view.backgroundColor = AppColor.brand
        addTapToDismissKeyboard()

        [
            rateLabel,
            currencySegmentedControl,
            taxCategorySegmentedControl,
            amountTextField,
            taxSegmentedControl,
            computeButton,
            resultLabel,
            useUntaxedButton,
            useTaxedButton,
            showShoppingListButton
        ].forEach(contentStackView.addArrangedSubview)

        view.addSubview(contentStackView)
        view.addSubview(updatedAtLabel)

        currencySegmentedControl.addTarget(self, action: #selector(currencyChanged), for: .valueChanged)
        taxCategorySegmentedControl.addTarget(self, action: #selector(taxCategoryChanged), for: .valueChanged)
        amountTextField.addTarget(self, action: #selector(amountTextChanged), for: .editingChanged)
        taxSegmentedControl.addTarget(self, action: #selector(taxModeChanged), for: .valueChanged)
        computeButton.addTarget(self, action: #selector(computeTapped), for: .touchUpInside)
        useUntaxedButton.addTarget(self, action: #selector(useUntaxedTapped), for: .touchUpInside)
        useTaxedButton.addTarget(self, action: #selector(useTaxedTapped), for: .touchUpInside)
        showShoppingListButton.addTarget(self, action: #selector(showShoppingListTapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.spacing),
            contentStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.horizontalInset),
            contentStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.horizontalInset),

            amountTextField.heightAnchor.constraint(equalToConstant: Constants.fieldHeight),

            updatedAtLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.horizontalInset),
            updatedAtLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.horizontalInset),
            updatedAtLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
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
                self?.resultLabel.text = text
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
        }
    }

    // MARK: - Actions

    @objc private func currencyChanged() {
        guard let currency = Currency(rawValue: currencySegmentedControl.selectedSegmentIndex) else { return }
        viewModel.input.currencyChanged(to: currency)
    }

    @objc private func taxCategoryChanged() {
        guard let category = TaxCategory(rawValue: taxCategorySegmentedControl.selectedSegmentIndex) else { return }
        viewModel.input.taxCategoryChanged(to: category)
    }

    @objc private func amountTextChanged() {
        viewModel.input.amountTextChanged(amountTextField.text ?? "")
    }

    @objc private func taxModeChanged() {
        guard let mode = TaxMode(rawValue: taxSegmentedControl.selectedSegmentIndex) else { return }
        viewModel.input.taxModeChanged(to: mode)
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

    // MARK: - Private

    /// 標籤帶有稅率百分比，會隨幣別改變，因此重建而非固定建立。
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

    private static func makeButton(title: String) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.background.backgroundColor = .white
        configuration.background.strokeColor = UIColor(white: 0.667, alpha: 1)
        configuration.background.strokeWidth = 3
        configuration.background.cornerRadius = 16
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}
