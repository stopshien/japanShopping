//
//  DetailViewController.swift
//  japanShopping
//

import Combine
import UIKit

final class DetailViewController: UIViewController {

    private enum Constants {
        static let horizontalInset: CGFloat = AppStyle.Spacing.normal
        static let spacing: CGFloat = 16
        static let photoHeight: CGFloat = 180
        static let photoBorderWidth: CGFloat = 4
        static let fieldHeight: CGFloat = 48
        static let pickerHeight: CGFloat = 99
        static let labelFontSize: CGFloat = 20
    }

    private let viewModel: DetailViewModelType
    private let factory: ScreenFactory
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Views

    private let imageSelectButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = AppColor.surface
        button.imageView?.contentMode = .scaleAspectFill
        button.clipsToBounds = true
        button.layer.cornerRadius = AppStyle.Radius.card
        button.setImage(UIImage(systemName: "photo"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let priceLabel = DetailViewController.makeLabel()
    private let productLabel = DetailViewController.makeLabel(text: "商品")
    private let payTypeLabel = DetailViewController.makeLabel(text: "付款方式")

    private let productTextField = AppView.textField()

    private let payTypePicker: UIPickerView = {
        let picker = UIPickerView()
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()

    private let cardsChooseButton: UIButton = {
        let button = AppView.secondaryButton(title: "請選擇信用卡")
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    private let editCardsButton = AppView.secondaryButton(title: "編輯信用卡")

    private let feedbackLabel = AppView.label(
        "信用卡回饋金額", font: AppStyle.Font.body, color: AppColor.textSecondary, alignment: .center
    )

    private let saveToListButton = AppView.primaryButton(title: "加入購物清單")
    private let showShoppingListButton = AppView.plainButton(title: "查看購物清單")
    private let formCard = AppView.card()

    private let cardButtonsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = Constants.spacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = Constants.spacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Init

    init(viewModel: DetailViewModelType, factory: ScreenFactory) {
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
        title = "購買明細"
        view.backgroundColor = AppColor.brand
        addTapToDismissKeyboard()

        payTypePicker.delegate = self
        payTypePicker.dataSource = self

        cardButtonsStackView.addArrangedSubview(cardsChooseButton)
        cardButtonsStackView.addArrangedSubview(editCardsButton)

        let cardStack = AppView.cardStack(in: formCard, spacing: AppStyle.Spacing.tight + 4)
        [
            priceLabel,
            makeRow(label: productLabel, field: productTextField),
            makeRow(label: payTypeLabel, field: payTypePicker),
            cardButtonsStackView,
            feedbackLabel,
            saveToListButton
        ].forEach(cardStack.addArrangedSubview)

        [imageSelectButton, formCard, showShoppingListButton].forEach(contentStackView.addArrangedSubview)

        view.addSubview(contentStackView)

        imageSelectButton.addTarget(self, action: #selector(imagePickerTapped), for: .touchUpInside)
        editCardsButton.addTarget(self, action: #selector(editCardsTapped), for: .touchUpInside)
        saveToListButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        showShoppingListButton.addTarget(self, action: #selector(showShoppingListTapped), for: .touchUpInside)
        productTextField.addTarget(self, action: #selector(productNameChanged), for: .editingChanged)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.spacing),
            contentStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.horizontalInset),
            contentStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.horizontalInset),

            imageSelectButton.heightAnchor.constraint(equalToConstant: Constants.photoHeight),
            productTextField.heightAnchor.constraint(equalToConstant: Constants.fieldHeight),
            payTypePicker.heightAnchor.constraint(equalToConstant: Constants.pickerHeight)
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.priceDescription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.priceLabel.text = text
            }
            .store(in: &cancellables)

        viewModel.output.isCardSectionVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isVisible in
                self?.cardButtonsStackView.isHidden = !isVisible
                self?.feedbackLabel.isHidden = !isVisible
            }
            .store(in: &cancellables)

        viewModel.output.cardButtonTitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                self?.cardsChooseButton.setTitle(title, for: .normal)
            }
            .store(in: &cancellables)

        viewModel.output.cardMenuItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.rebuildCardMenu(with: items)
            }
            .store(in: &cancellables)

        viewModel.output.feedbackText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.feedbackLabel.text = text
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

    private func navigate(to route: DetailRoute) {
        switch route {
        case .addCard:
            let controller = factory.makeCardSet { [weak self] in
                self?.viewModel.input.reloadCards()
            }
            navigationController?.pushViewController(controller, animated: true)

        case .editCards:
            let controller = factory.makeCardList { [weak self] in
                self?.viewModel.input.reloadCards()
            }
            navigationController?.pushViewController(controller, animated: true)

        case .shoppingList:
            navigationController?.pushViewController(factory.makeShoppingList(), animated: true)
        }
    }

    // MARK: - Actions

    @objc private func imagePickerTapped() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        present(imagePickerController, animated: true)
    }

    @objc private func editCardsTapped() {
        viewModel.input.editCardsTapped()
    }

    @objc private func saveTapped() {
        view.endEditing(true)
        viewModel.input.saveTapped()
    }

    @objc private func showShoppingListTapped() {
        viewModel.input.showShoppingListTapped()
    }

    @objc private func productNameChanged() {
        viewModel.input.productNameChanged(productTextField.text ?? "")
    }

    // MARK: - Private

    private func rebuildCardMenu(with items: [CardMenuItem]) {
        var actions = [UIAction(title: "新增信用卡") { [weak self] _ in
            self?.viewModel.input.addCardTapped()
        }]

        for (index, item) in items.enumerated() {
            actions.append(UIAction(title: item.title) { [weak self] _ in
                self?.viewModel.input.cardSelected(at: index)
            })
        }

        cardsChooseButton.menu = UIMenu(children: actions)
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    private func makeRow(label: UILabel, field: UIView) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [label, field])
        row.axis = .horizontal
        row.spacing = Constants.spacing
        row.alignment = .center
        return row
    }

    private static func makeLabel(text: String? = nil) -> UILabel {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = AppStyle.Font.bodyEmphasis
        label.textColor = AppColor.textPrimary
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

}

// MARK: - UIPickerViewDataSource

extension DetailViewController: UIPickerViewDataSource {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        2
    }
}

// MARK: - UIPickerViewDelegate

extension DetailViewController: UIPickerViewDelegate {

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        row == 0 ? "現金" : "信用卡"
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        viewModel.input.payMethodSelected(row: row)
    }
}

// MARK: - UIImagePickerControllerDelegate

extension DetailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        if let image = info[.originalImage] as? UIImage {
            imageSelectButton.setImage(image, for: .normal)
            viewModel.input.photoSelected(image.jpegData(compressionQuality: 0.9))
        }
        dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
}
