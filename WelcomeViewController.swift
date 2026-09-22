//
//  WelcomeViewController.swift
//  japanShopping
//

import Combine
import UIKit

/// 首次啟動時顯示，請使用者輸入稱呼。
/// 完成後由 SceneDelegate 換掉 root，之後不會再出現。
final class WelcomeViewController: UIViewController {

    private enum Constants {
        static let fieldHeight: CGFloat = 48
        static let iconSize: CGFloat = 64
    }

    private let viewModel: WelcomeViewModelType
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Views

    private let iconView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: Constants.iconSize, weight: .regular)
        let imageView = UIImageView(image: UIImage(systemName: "cart.fill", withConfiguration: configuration))
        imageView.tintColor = AppColor.accent
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel = AppView.label(
        "歡迎使用", font: AppStyle.Font.title, alignment: .center
    )

    private let subtitleLabel = AppView.label(
        "先告訴我們該怎麼稱呼你",
        font: AppStyle.Font.body,
        color: AppColor.textSecondary,
        alignment: .center
    )

    private let inputCard = AppView.card()

    private let nameTextField: UITextField = {
        let textField = AppView.textField()
        textField.placeholder = "你的名字"
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        return textField
    }()

    private let startButton = AppView.primaryButton(title: "下一步")

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = AppStyle.Spacing.normal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Init

    init(viewModel: WelcomeViewModelType) {
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameTextField.becomeFirstResponder()
    }

    // MARK: - Setup

    private func setupViews() {
        view.backgroundColor = AppColor.brand
        addTapToDismissKeyboard()

        let cardStack = AppView.cardStack(in: inputCard)
        [nameTextField, startButton].forEach(cardStack.addArrangedSubview)

        [iconView, titleLabel, subtitleLabel, inputCard].forEach(contentStackView.addArrangedSubview)
        contentStackView.setCustomSpacing(AppStyle.Spacing.tight, after: titleLabel)
        contentStackView.setCustomSpacing(AppStyle.Spacing.loose, after: subtitleLabel)

        view.addSubview(contentStackView)

        nameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        nameTextField.addTarget(self, action: #selector(startTapped), for: .editingDidEndOnExit)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            contentStackView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: AppStyle.Spacing.loose
            ),
            contentStackView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -AppStyle.Spacing.loose
            ),

            iconView.heightAnchor.constraint(equalToConstant: Constants.iconSize),
            nameTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.fieldHeight)
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.isStartEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.startButton.isEnabled = isEnabled
            }
            .store(in: &cancellables)

    }

    /// 帶著輸入的名字進入下一步。收鍵盤避免推頁時殘留。
    func bindFinish(_ handler: @escaping (String) -> Void) {
        viewModel.output.didFinish
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                self?.view.endEditing(true)
                handler(name)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func nameChanged() {
        viewModel.input.nameChanged(nameTextField.text ?? "")
    }

    @objc private func startTapped() {
        viewModel.input.startTapped()
    }

    // MARK: - Private

}
