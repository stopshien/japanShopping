//
//  ItemEditorViewController.swift
//  japanShopping
//

import Combine
import UIKit

/// 從消費紀錄點選一筆後開啟。可改商品名稱與照片，價格與付款方式只顯示。
final class ItemEditorViewController: UIViewController {

    private enum Constants {
        static let photoHeight: CGFloat = 180
        static let fieldHeight: CGFloat = 48
        static let jpegQuality: CGFloat = 0.9
    }

    private let viewModel: ItemEditorViewModelType
    private var cancellables = Set<AnyCancellable>()

    /// 按下「儲存」且資料有效時呼叫，之後畫面自行返回清單。
    var onSave: ((ItemEdit) -> Void)?

    // MARK: - Views

    private let photoButton = PhotoButton(accessibilityLabel: "更換照片")

    private let formCard = AppView.card()

    private let productNameLabel = AppView.label("商品", font: AppStyle.Font.label, color: AppColor.textSecondary)
    private let productNameTextField = AppView.textField()

    // 唯讀欄位刻意只用文字呈現，不用輸入框或選單，避免看起來可以修改。
    private let priceValueLabel = AppView.label(font: AppStyle.Font.bodyEmphasis, alignment: .right)
    private let payTypeValueLabel = AppView.label(font: AppStyle.Font.bodyEmphasis, alignment: .right)
    private let lockedNoteLabel = AppView.label(
        "價格與付款方式已用於計算信用卡回饋，無法修改",
        font: AppStyle.Font.caption,
        color: AppColor.textSecondary
    )

    private let saveButton = AppView.primaryButton(title: "儲存")

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = AppStyle.Spacing.normal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Init

    init(viewModel: ItemEditorViewModelType) {
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
        title = "編輯明細"
        view.backgroundColor = AppColor.brand
        addTapToDismissKeyboard()

        let formStack = AppView.cardStack(in: formCard, spacing: AppStyle.Spacing.tight)
        [
            productNameLabel,
            productNameTextField,
            makeReadOnlyRow(title: "價格", valueLabel: priceValueLabel),
            makeReadOnlyRow(title: "付款方式", valueLabel: payTypeValueLabel),
            lockedNoteLabel,
            saveButton
        ].forEach(formStack.addArrangedSubview)
        formStack.setCustomSpacing(AppStyle.Spacing.normal, after: productNameTextField)
        formStack.setCustomSpacing(AppStyle.Spacing.normal, after: lockedNoteLabel)

        [photoButton, formCard].forEach(contentStackView.addArrangedSubview)
        view.addSubview(contentStackView)

        photoButton.addTarget(self, action: #selector(photoTapped), for: .touchUpInside)
        productNameTextField.addTarget(self, action: #selector(productNameChanged), for: .editingChanged)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppStyle.Spacing.normal
            ),
            contentStackView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: AppStyle.Spacing.normal
            ),
            contentStackView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -AppStyle.Spacing.normal
            ),

            photoButton.heightAnchor.constraint(equalToConstant: Constants.photoHeight),
            productNameTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.fieldHeight)
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.productName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                self?.productNameTextField.text = name
            }
            .store(in: &cancellables)

        viewModel.output.priceDescription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.priceValueLabel.text = text
            }
            .store(in: &cancellables)

        viewModel.output.payTypeDescription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.payTypeValueLabel.text = text
            }
            .store(in: &cancellables)

        viewModel.output.photoData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                guard let data, let image = UIImage(data: data) else { return }
                self?.photoButton.setPhoto(image)
            }
            .store(in: &cancellables)

        viewModel.output.isSaveEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.saveButton.isEnabled = isEnabled
            }
            .store(in: &cancellables)

        viewModel.output.didSave
            .receive(on: DispatchQueue.main)
            .sink { [weak self] edit in
                self?.onSave?(edit)
                self?.navigationController?.popViewController(animated: true)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func photoTapped() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        present(imagePickerController, animated: true)
    }

    @objc private func productNameChanged() {
        viewModel.input.productNameChanged(productNameTextField.text ?? "")
    }

    @objc private func saveTapped() {
        view.endEditing(true)
        viewModel.input.saveTapped()
    }

    // MARK: - Private

    private func makeReadOnlyRow(title: String, valueLabel: UILabel) -> UIStackView {
        let titleLabel = AppView.label(title, font: AppStyle.Font.label, color: AppColor.textSecondary)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        row.axis = .horizontal
        row.spacing = AppStyle.Spacing.normal
        row.alignment = .firstBaseline
        return row
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ItemEditorViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        if let image = info[.originalImage] as? UIImage {
            viewModel.input.photoSelected(image.jpegData(compressionQuality: Constants.jpegQuality))
        }
        dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
}
