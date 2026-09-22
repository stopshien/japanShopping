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
        /// 照片改成一列後的縮圖大小。
        static let photoThumbnailSize: CGFloat = 72
        static let photoBorderWidth: CGFloat = 4
        static let fieldHeight: CGFloat = 48
        static let segmentHeight: CGFloat = 36
        static let labelFontSize: CGFloat = 20
    }

    private let viewModel: DetailViewModelType
    private let factory: ScreenFactory
    private var cancellables = Set<AnyCancellable>()
    /// 標籤＋欄位的每一列，字級改變時要重新決定排列方向。
    private var fieldRows: [UIStackView] = []
    /// 信用卡按鈕的第二行，setTitle 重建 configuration 後要補回去。
    private var cardSubtitle = ""

    /// 商品成功加入購物清單時呼叫。
    var onSaved: (() -> Void)?

    // MARK: - Views

    private let imageSelectButton: PhotoButton = {
        let button = PhotoButton(accessibilityLabel: "選擇照片")
        // 白色卡片上的白色縮圖看不出是可點區塊。
        button.backgroundColor = AppColor.accentSoft
        return button
    }()
    /// 照片那一列的說明，選了照片後改為「更換照片」。
    private let photoActionLabel = AppView.label("加入照片", color: AppColor.accent)

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    /// 這頁最重要的資訊之一，用和首頁一致的大字金額。
    private let priceLabel = AppView.label(font: AppStyle.Font.resultNumber)
    private let priceTaxStateLabel = AppView.label(font: AppStyle.Font.label, color: AppColor.textSecondary)
    private let productLabel = DetailViewController.makeLabel(text: "商品（必填）")
    private let payTypeLabel = DetailViewController.makeLabel(text: "付款方式")

    private let productTextField: UITextField = {
        let textField = AppView.textField()
        textField.placeholder = "例如：抹茶捲"
        return textField
    }()

    /// 只有現金與信用卡兩個選項，用分段控制比滾輪快，也和首頁一致。
    private let payTypeSegmentedControl = AppView.segmentedControl(items: ["現金", "信用卡"])

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


        let photoRow = UIStackView(arrangedSubviews: [imageSelectButton, photoActionLabel])
        photoRow.axis = .horizontal
        photoRow.alignment = .center
        photoRow.spacing = Constants.spacing
        photoRow.isUserInteractionEnabled = true
        photoRow.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(imagePickerTapped))
        )

        let cardStack = AppView.cardStack(in: formCard, spacing: AppStyle.Spacing.tight + 4)
        [
            priceLabel,
            priceTaxStateLabel,
            photoRow,
            makeRow(label: productLabel, field: productTextField),
            makeRow(label: payTypeLabel, field: payTypeSegmentedControl),
            cardsChooseButton,
            feedbackLabel,
            saveToListButton
        ].forEach(cardStack.addArrangedSubview)

        cardStack.setCustomSpacing(AppStyle.Spacing.normal, after: priceTaxStateLabel)
        cardStack.setCustomSpacing(AppStyle.Spacing.normal, after: photoRow)

        contentStackView.addArrangedSubview(formCard)

        scrollView.addSubview(contentStackView)
        view.addSubview(scrollView)

        payTypeSegmentedControl.selectedSegmentIndex = 0
        payTypeSegmentedControl.addTarget(self, action: #selector(payMethodChanged), for: .valueChanged)
        imageSelectButton.addTarget(self, action: #selector(imagePickerTapped), for: .touchUpInside)
        saveToListButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        productTextField.addTarget(self, action: #selector(productNameChanged), for: .editingChanged)
    }

    private func setupConstraints() {
        let content = scrollView.contentLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // 鍵盤出現時可視範圍縮到鍵盤上緣，被擋住的按鈕可以捲出來。
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            // 內容區要有寬度，否則 contentSize.width 為 0，捲動計算會失效。
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentStackView.topAnchor.constraint(equalTo: content.topAnchor, constant: Constants.spacing),
            contentStackView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Constants.spacing),
            contentStackView.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Constants.horizontalInset
            ),
            contentStackView.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Constants.horizontalInset
            ),

            imageSelectButton.widthAnchor.constraint(equalToConstant: Constants.photoThumbnailSize),
            imageSelectButton.heightAnchor.constraint(equalToConstant: Constants.photoThumbnailSize),
            productTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.fieldHeight),
            payTypeSegmentedControl.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Constants.segmentHeight
            )
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        // 鍵盤出現後可視範圍變小，把輸入框與「加入消費紀錄」捲進畫面。
        NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.keepFormVisible()
            }
            .store(in: &cancellables)

        viewModel.output.priceAmount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.priceLabel.text = text
            }
            .store(in: &cancellables)

        viewModel.output.priceTaxState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.priceTaxStateLabel.text = text
            }
            .store(in: &cancellables)

        viewModel.output.isSaveEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.saveToListButton.isEnabled = isEnabled
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
                guard let self else { return }
                self.cardsChooseButton.setTitle(title, for: .normal)
                // setTitle 會重建 configuration，第二行要跟著重設。
                AppView.setSubtitle(self.cardSubtitle, on: self.cardsChooseButton)
            }
            .store(in: &cancellables)

        viewModel.output.cardButtonSubtitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subtitle in
                guard let self else { return }
                self.cardSubtitle = subtitle
                AppView.setSubtitle(subtitle, on: self.cardsChooseButton)
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

    @objc private func payMethodChanged() {
        viewModel.input.payMethodSelected(row: payTypeSegmentedControl.selectedSegmentIndex)
    }

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
    /// 鍵盤開著時，讓商品名稱與儲存按鈕都留在可視範圍內。
    private func keepFormVisible() {
        guard productTextField.isFirstResponder, view.window != nil else { return }
        view.layoutIfNeeded()

        let field = productTextField.convert(productTextField.bounds, to: scrollView)
        let button = saveToListButton.convert(saveToListButton.bounds, to: scrollView)
        let margin = AppStyle.Spacing.tight
        let visibleHeight = scrollView.bounds.height
            - scrollView.adjustedContentInset.top - scrollView.adjustedContentInset.bottom
        // 兩者都放不下時以輸入框為主，使用者正在打字。
        let target = field.union(button).height + margin * 2 <= visibleHeight ? field.union(button) : field
        scrollView.scrollRectToVisible(target.insetBy(dx: 0, dy: -margin), animated: true)
    }

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

// MARK: - UIImagePickerControllerDelegate

extension DetailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        if let image = info[.originalImage] as? UIImage {
            imageSelectButton.setPhoto(image)
            photoActionLabel.text = "更換照片"
            viewModel.input.photoSelected(image.jpegData(compressionQuality: 0.9))
        }
        dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
}
