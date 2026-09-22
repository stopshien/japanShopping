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
    /// 標籤＋欄位的每一列，字級改變時要重新決定排列方向。
    private var fieldRows: [UIStackView] = []

    /// 商品成功加入購物清單時呼叫。
    var onSaved: (() -> Void)?

    // MARK: - Views

    private let imageSelectButton = PhotoButton(accessibilityLabel: "選擇照片")

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


    private let feedbackLabel = AppView.label(
        "信用卡回饋金額", font: AppStyle.Font.body, color: AppColor.textSecondary, alignment: .center
    )

    private let saveToListButton = AppView.primaryButton(title: "加入消費紀錄")
    private let formCard = AppView.card()

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

    /// 專案支援 iOS 15，所以用 traitCollectionDidChange 而不是 iOS 17 的 registerForTraitChanges。
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        guard traitCollection.preferredContentSizeCategory != previous?.preferredContentSizeCategory else { return }
        fieldRows.forEach(applyAxis(to:))
    }

    // MARK: - Setup

    private func setupViews() {
        title = "購買明細"
        view.backgroundColor = AppColor.brand
        navigationItem.rightBarButtonItem = AppView.barButton(
            systemImage: "cart",
            accessibilityLabel: "查看消費紀錄",
            target: self,
            action: #selector(showShoppingListTapped)
        )
        addTapToDismissKeyboard()

        payTypePicker.delegate = self
        payTypePicker.dataSource = self

        let cardStack = AppView.cardStack(in: formCard, spacing: AppStyle.Spacing.tight + 4)
        [
            priceLabel,
            makeRow(label: productLabel, field: productTextField),
            makeRow(label: payTypeLabel, field: payTypePicker),
            cardsChooseButton,
            feedbackLabel,
            saveToListButton
        ].forEach(cardStack.addArrangedSubview)

        [imageSelectButton, formCard].forEach(contentStackView.addArrangedSubview)

        view.addSubview(contentStackView)

        imageSelectButton.addTarget(self, action: #selector(imagePickerTapped), for: .touchUpInside)
        saveToListButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        productTextField.addTarget(self, action: #selector(productNameChanged), for: .editingChanged)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.spacing),
            contentStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.horizontalInset),
            contentStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.horizontalInset),

            imageSelectButton.heightAnchor.constraint(equalToConstant: Constants.photoHeight),
            productTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.fieldHeight),
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
                self?.cardsChooseButton.isHidden = !isVisible
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

        case .shoppingList:
            navigationController?.pushViewController(factory.makeShoppingList(allowsBack: true), animated: true)

        case .savedToShoppingList:
            // 存檔成功給一下「成功」的觸覺回饋，不看螢幕也知道已經記下來了。
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved?()
            navigationController?.pushViewController(factory.makeShoppingList(allowsBack: false), animated: true)
        }
    }

    // MARK: - Actions

    @objc private func imagePickerTapped() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        present(imagePickerController, animated: true)
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

    /// 標籤與欄位並排；大字級時欄位會被擠到只剩幾個字，改成上下排列。
    private func makeRow(label: UILabel, field: UIView) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [label, field])
        row.spacing = Constants.spacing
        fieldRows.append(row)
        applyAxis(to: row)
        return row
    }

    private func applyAxis(to row: UIStackView) {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        row.axis = isAccessibilitySize ? .vertical : .horizontal
        row.alignment = isAccessibilitySize ? .fill : .center
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
            imageSelectButton.setPhoto(image)
            viewModel.input.photoSelected(image.jpegData(compressionQuality: 0.9))
        }
        dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
}
