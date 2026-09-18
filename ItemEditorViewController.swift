//
//  ItemEditorViewController.swift
//  japanShopping
//

import Combine
import UIKit

/// 從購物清單點選一筆消費後開啟，修改商品細節。
final class ItemEditorViewController: UIViewController {

    private enum Constants {
        static let photoHeight: CGFloat = 180
        static let fieldHeight: CGFloat = 48
        static let segmentHeight: CGFloat = 36
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
    private let priceLabel = AppView.label("台幣價格", font: AppStyle.Font.label, color: AppColor.textSecondary)
    private let priceTextField = AppView.textField(keyboardType: .decimalPad)
    private let taxSegmentedControl = AppView.segmentedControl(items: TaxMode.allCases.map(\.title))
    private let payTypeLabel = AppView.label("付款方式", font: AppStyle.Font.label, color: AppColor.textSecondary)

    private let payTypeButton: UIButton = {
        let button = AppView.secondaryButton(title: "")
        button.showsMenuAsPrimaryAction = true
        return button
    }()

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
        viewModel.input.viewDidLoad()
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
            priceLabel,
            priceTextField,
            taxSegmentedControl,
            payTypeLabel,
            payTypeButton,
            saveButton
        ].forEach(formStack.addArrangedSubview)
        formStack.setCustomSpacing(AppStyle.Spacing.normal, after: productNameTextField)
        formStack.setCustomSpacing(AppStyle.Spacing.normal, after: taxSegmentedControl)
        formStack.setCustomSpacing(AppStyle.Spacing.normal, after: payTypeButton)

        [photoButton, formCard].forEach(contentStackView.addArrangedSubview)
        view.addSubview(contentStackView)

        photoButton.addTarget(self, action: #selector(photoTapped), for: .touchUpInside)
        productNameTextField.addTarget(self, action: #selector(productNameChanged), for: .editingChanged)
        priceTextField.addTarget(self, action: #selector(priceChanged), for: .editingChanged)
        taxSegmentedControl.addTarget(self, action: #selector(taxModeChanged), for: .valueChanged)
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
            productNameTextField.heightAnchor.constraint(equalToConstant: Constants.fieldHeight),
            priceTextField.heightAnchor.constraint(equalToConstant: Constants.fieldHeight),
            taxSegmentedControl.heightAnchor.constraint(equalToConstant: Constants.segmentHeight)
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

        viewModel.output.priceText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.priceTextField.text = text
            }
            .store(in: &cancellables)

        viewModel.output.selectedTaxMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.taxSegmentedControl.selectedSegmentIndex = mode?.rawValue ?? UISegmentedControl.noSegment
            }
            .store(in: &cancellables)

        viewModel.output.payTypeTitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                self?.payTypeButton.setTitle(title, for: .normal)
            }
            .store(in: &cancellables)

        viewModel.output.payTypeOptions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] options in
                self?.rebuildPayTypeMenu(with: options)
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

        viewModel.output.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.presentError(message)
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

    @objc private func priceChanged() {
        viewModel.input.priceTextChanged(priceTextField.text ?? "")
    }

    @objc private func taxModeChanged() {
        guard let mode = TaxMode(rawValue: taxSegmentedControl.selectedSegmentIndex) else { return }
        viewModel.input.taxModeChanged(to: mode)
    }

    @objc private func saveTapped() {
        view.endEditing(true)
        viewModel.input.saveTapped()
    }

    // MARK: - Private

    private func rebuildPayTypeMenu(with options: [String]) {
        let actions = options.enumerated().map { index, title in
            UIAction(title: title) { [weak self] _ in
                self?.viewModel.input.payTypeSelected(at: index)
            }
        }
        payTypeButton.menu = UIMenu(children: actions)
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
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
