//
//  CardSetViewController.swift
//  japanShopping
//

import Combine
import UIKit

final class CardSetViewController: UIViewController {

    private enum Constants {
        static let spacing: CGFloat = 16
        static let horizontalInset: CGFloat = 24
        static let topInset: CGFloat = 32
        static let fieldHeight: CGFloat = 44
    }

    /// 新增成功並返回前呼叫，讓上一頁知道資料已變更。
    var onFinish: (() -> Void)?

    private let viewModel: CardSetViewModelType
    private var cancellables = Set<AnyCancellable>()

    private let cardNameTextField = CardSetViewController.makeTextField(placeholder: "信用卡名稱")
    private let moneyBackTextField = CardSetViewController.makeTextField(placeholder: "回饋趴數（例如 3.5）", keyboardType: .decimalPad)
    private let limitTextField = CardSetViewController.makeTextField(placeholder: "回饋上限金額", keyboardType: .decimalPad)

    private let addButton: UIButton = {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = "新增信用卡"
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = Constants.spacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    init(viewModel: CardSetViewModelType) {
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
    }

    // MARK: - Setup

    private func setupViews() {
        title = "新增信用卡"
        view.backgroundColor = .systemBackground
        addTapToDismissKeyboard()

        [cardNameTextField, moneyBackTextField, limitTextField, addButton].forEach(stackView.addArrangedSubview)
        view.addSubview(stackView)

        cardNameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        moneyBackTextField.addTarget(self, action: #selector(percentChanged), for: .editingChanged)
        limitTextField.addTarget(self, action: #selector(limitChanged), for: .editingChanged)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.topInset),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.horizontalInset),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.horizontalInset),
            cardNameTextField.heightAnchor.constraint(equalToConstant: Constants.fieldHeight),
            moneyBackTextField.heightAnchor.constraint(equalToConstant: Constants.fieldHeight),
            limitTextField.heightAnchor.constraint(equalToConstant: Constants.fieldHeight)
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.isAddEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.addButton.isEnabled = isEnabled
            }
            .store(in: &cancellables)

        viewModel.output.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.presentError(message)
            }
            .store(in: &cancellables)

        viewModel.output.didAddCard
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.onFinish?()
                self?.navigationController?.popViewController(animated: true)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func nameChanged() {
        viewModel.input.nameChanged(cardNameTextField.text ?? "")
    }

    @objc private func percentChanged() {
        viewModel.input.percentChanged(moneyBackTextField.text ?? "")
    }

    @objc private func limitChanged() {
        viewModel.input.limitChanged(limitTextField.text ?? "")
    }

    @objc private func addTapped() {
        view.endEditing(true)
        viewModel.input.addTapped()
    }

    // MARK: - Private

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    private static func makeTextField(placeholder: String, keyboardType: UIKeyboardType = .default) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.keyboardType = keyboardType
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }
}
