//
//  SettingsViewController.swift
//  japanShopping
//

import Combine
import UIKit

final class SettingsViewController: UIViewController {

    private enum Constants {
        static let fieldHeight: CGFloat = 48
        static let segmentHeight: CGFloat = 40
    }

    /// 儲存並返回前呼叫，讓上一頁重新載入設定。
    var onFinish: (() -> Void)?

    private let viewModel: SettingsViewModelType
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Views

    private let card = AppView.card()
    private let nameTitleLabel = AppView.label("稱呼", font: AppStyle.Font.label, color: AppColor.textSecondary)
    private let currencyTitleLabel = AppView.label("幣別", font: AppStyle.Font.label, color: AppColor.textSecondary)

    private let nameTextField: UITextField = {
        let textField = AppView.textField()
        textField.placeholder = "你的名字"
        textField.returnKeyType = .done
        return textField
    }()

    private let currencySegmentedControl = AppView.segmentedControl(items: Currency.allCases.map(\.title))
    private let saveButton = AppView.primaryButton(title: "儲存")

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = AppStyle.Spacing.normal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Init

    init(viewModel: SettingsViewModelType) {
        self.viewModel = viewModel
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
        title = "設定"
        view.backgroundColor = AppColor.brand
        addTapToDismissKeyboard()

        let cardStack = AppView.cardStack(in: card, spacing: AppStyle.Spacing.tight)
        [nameTitleLabel, nameTextField, currencyTitleLabel, currencySegmentedControl, saveButton]
            .forEach(cardStack.addArrangedSubview)
        cardStack.setCustomSpacing(AppStyle.Spacing.normal, after: nameTextField)
        cardStack.setCustomSpacing(AppStyle.Spacing.normal, after: currencySegmentedControl)

        contentStackView.addArrangedSubview(card)
        view.addSubview(contentStackView)

        nameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        currencySegmentedControl.addTarget(self, action: #selector(currencyChanged), for: .valueChanged)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
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
            nameTextField.heightAnchor.constraint(equalToConstant: Constants.fieldHeight),
            currencySegmentedControl.heightAnchor.constraint(equalToConstant: Constants.segmentHeight)
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.name
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                self?.nameTextField.text = name
            }
            .store(in: &cancellables)

        viewModel.output.selectedCurrency
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currency in
                self?.currencySegmentedControl.selectedSegmentIndex = currency.rawValue
            }
            .store(in: &cancellables)

        viewModel.output.isSaveEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.saveButton.isEnabled = isEnabled
            }
            .store(in: &cancellables)

        viewModel.output.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.presentError(message)
            }
            .store(in: &cancellables)

        viewModel.output.didFinish
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.onFinish?()
                self?.navigationController?.popViewController(animated: true)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func nameChanged() {
        viewModel.input.nameChanged(nameTextField.text ?? "")
    }

    @objc private func currencyChanged() {
        guard let currency = Currency(rawValue: currencySegmentedControl.selectedSegmentIndex) else { return }
        viewModel.input.currencySelected(currency)
    }

    @objc private func saveTapped() {
        view.endEditing(true)
        viewModel.input.saveTapped()
    }

    // MARK: - Private

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}
