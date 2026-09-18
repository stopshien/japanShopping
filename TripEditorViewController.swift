//
//  TripEditorViewController.swift
//  japanShopping
//

import Combine
import UIKit

/// 建立或修改專案。引導流程的第二步與專案清單的「新增」共用這個畫面，
/// 差別只在標題與說明文字。
final class TripEditorViewController: UIViewController {

    struct Presentation {
        let heading: String
        let subheading: String
        let confirmTitle: String

        static let onboarding = Presentation(
            heading: "這趟要去哪裡？",
            subheading: "建立第一個專案，之後可以再新增",
            confirmTitle: "開始使用"
        )

        static let create = Presentation(
            heading: "新的旅行",
            subheading: "選擇這趟要換算的幣別",
            confirmTitle: "建立專案"
        )

        static let edit = Presentation(
            heading: "編輯專案",
            subheading: "更改名稱或幣別",
            confirmTitle: "儲存"
        )
    }

    private enum Constants {
        static let iconSize: CGFloat = 56
        static let fieldHeight: CGFloat = 48
        static let segmentHeight: CGFloat = 40
    }

    private let viewModel: TripEditorViewModelType
    private let presentation: Presentation
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Views

    private let iconView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: Constants.iconSize, weight: .regular)
        let imageView = UIImageView(
            image: UIImage(systemName: "airplane.departure", withConfiguration: configuration)
        )
        imageView.tintColor = AppColor.accent
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let headingLabel = AppView.label(font: AppStyle.Font.title, alignment: .center)
    private let subheadingLabel = AppView.label(
        font: AppStyle.Font.body, color: AppColor.textSecondary, alignment: .center
    )

    private let card = AppView.card()
    private let nameTitleLabel = AppView.label("專案名稱", font: AppStyle.Font.label, color: AppColor.textSecondary)
    private let currencyTitleLabel = AppView.label("幣別", font: AppStyle.Font.label, color: AppColor.textSecondary)

    private let nameTextField: UITextField = {
        let textField = AppView.textField()
        textField.placeholder = "例如：東京賞櫻"
        textField.returnKeyType = .done
        return textField
    }()

    private let currencySegmentedControl = AppView.segmentedControl(items: Currency.allCases.map(\.title))
    private let taxDescriptionLabel = AppView.label(
        font: AppStyle.Font.caption, color: AppColor.textSecondary, alignment: .center
    )
    private let confirmButton: UIButton

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = AppStyle.Spacing.normal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Init

    init(viewModel: TripEditorViewModelType, presentation: Presentation) {
        self.viewModel = viewModel
        self.presentation = presentation
        self.confirmButton = AppView.primaryButton(title: presentation.confirmTitle)
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
        headingLabel.text = presentation.heading
        subheadingLabel.text = presentation.subheading

        view.backgroundColor = AppColor.brand
        addTapToDismissKeyboard()

        let cardStack = AppView.cardStack(in: card, spacing: AppStyle.Spacing.tight)
        [nameTitleLabel, nameTextField, currencyTitleLabel, currencySegmentedControl,
         taxDescriptionLabel, confirmButton].forEach(cardStack.addArrangedSubview)
        cardStack.setCustomSpacing(AppStyle.Spacing.normal, after: nameTextField)
        cardStack.setCustomSpacing(AppStyle.Spacing.normal, after: taxDescriptionLabel)

        [iconView, headingLabel, subheadingLabel, card].forEach(contentStackView.addArrangedSubview)
        contentStackView.setCustomSpacing(AppStyle.Spacing.tight, after: headingLabel)
        contentStackView.setCustomSpacing(AppStyle.Spacing.loose, after: subheadingLabel)

        view.addSubview(contentStackView)

        nameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        currencySegmentedControl.addTarget(self, action: #selector(currencyChanged), for: .valueChanged)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
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
            iconView.heightAnchor.constraint(equalToConstant: Constants.iconSize),
            nameTextField.heightAnchor.constraint(equalToConstant: Constants.fieldHeight),
            currencySegmentedControl.heightAnchor.constraint(equalToConstant: Constants.segmentHeight)
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.name
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                guard self?.nameTextField.text != name else { return }
                self?.nameTextField.text = name
            }
            .store(in: &cancellables)

        viewModel.output.selectedCurrency
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currency in
                self?.currencySegmentedControl.selectedSegmentIndex = currency.rawValue
            }
            .store(in: &cancellables)

        viewModel.output.taxDescription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.taxDescriptionLabel.text = text
            }
            .store(in: &cancellables)

        viewModel.output.isConfirmEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.confirmButton.isEnabled = isEnabled
            }
            .store(in: &cancellables)

        viewModel.output.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.presentError(message)
            }
            .store(in: &cancellables)
    }

    func bindFinish(_ handler: @escaping () -> Void) {
        viewModel.output.didFinish
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.view.endEditing(true)
                handler()
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

    @objc private func confirmTapped() {
        view.endEditing(true)
        viewModel.input.confirmTapped()
    }

    // MARK: - Private

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}
