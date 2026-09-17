//
//  CurrencySelectionViewController.swift
//  japanShopping
//

import Combine
import UIKit

/// 引導流程的第二步：選擇這趟要換算的幣別。
final class CurrencySelectionViewController: UIViewController {

    private enum Constants {
        static let iconSize: CGFloat = 64
        static let segmentHeight: CGFloat = 44
    }

    private let viewModel: CurrencySelectionViewModelType
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Views

    private let iconView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: Constants.iconSize, weight: .regular)
        let imageView = UIImageView(
            image: UIImage(systemName: "yensign.circle.fill", withConfiguration: configuration)
        )
        imageView.tintColor = AppColor.accent
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel = AppView.label("這趟要去哪裡？", font: AppStyle.Font.title, alignment: .center)
    private let subtitleLabel = AppView.label(
        "選擇要換算的幣別，之後可以在設定裡更改",
        font: AppStyle.Font.body,
        color: AppColor.textSecondary,
        alignment: .center
    )

    private let inputCard = AppView.card()
    private let currencySegmentedControl = AppView.segmentedControl(items: Currency.allCases.map(\.title))
    private let descriptionLabel = AppView.label(
        font: AppStyle.Font.caption, color: AppColor.textSecondary, alignment: .center
    )
    private let confirmButton = AppView.primaryButton(title: "開始使用")

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = AppStyle.Spacing.normal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Init

    init(viewModel: CurrencySelectionViewModelType) {
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
        view.backgroundColor = AppColor.brand

        let cardStack = AppView.cardStack(in: inputCard)
        [currencySegmentedControl, descriptionLabel, confirmButton].forEach(cardStack.addArrangedSubview)

        [iconView, titleLabel, subtitleLabel, inputCard].forEach(contentStackView.addArrangedSubview)
        contentStackView.setCustomSpacing(AppStyle.Spacing.tight, after: titleLabel)
        contentStackView.setCustomSpacing(AppStyle.Spacing.loose, after: subtitleLabel)

        view.addSubview(contentStackView)

        currencySegmentedControl.addTarget(self, action: #selector(currencyChanged), for: .valueChanged)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            contentStackView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: AppStyle.Spacing.loose
            ),
            contentStackView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -AppStyle.Spacing.loose
            ),
            iconView.heightAnchor.constraint(equalToConstant: Constants.iconSize),
            currencySegmentedControl.heightAnchor.constraint(equalToConstant: Constants.segmentHeight)
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.selectedCurrency
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currency in
                self?.currencySegmentedControl.selectedSegmentIndex = currency.rawValue
            }
            .store(in: &cancellables)

        viewModel.output.currencyDescription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.descriptionLabel.text = text
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
            .sink { handler() }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func currencyChanged() {
        guard let currency = Currency(rawValue: currencySegmentedControl.selectedSegmentIndex) else { return }
        viewModel.input.currencySelected(currency)
    }

    @objc private func confirmTapped() {
        viewModel.input.confirmTapped()
    }

    // MARK: - Private

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}
