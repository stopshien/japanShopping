//
//  CardSetViewController.swift
//  japanShopping
//

import Combine
import UIKit

/// 新增或編輯信用卡：卡片名稱，加上一個或多個回饋方案。
///
/// 只有一個方案時，畫面和以前一樣簡單：名稱、趴數、上限。
/// 可切換權益的卡（例如台新 Richart）再按「新增方案」加入其他方案。
final class CardSetViewController: UIViewController {

    private enum Constants {
        static let spacing: CGFloat = AppStyle.Spacing.normal
        static let horizontalInset: CGFloat = AppStyle.Spacing.normal
        static let fieldHeight: CGFloat = 48
    }

    /// 新增成功後呼叫。之後要返回還是前往下一步由呼叫端決定。
    var onFinish: (() -> Void)?
    /// 有設定時導覽列顯示「略過」，用於引導流程中可跳過的情境。
    var onSkip: (() -> Void)?

    private let viewModel: CardSetViewModelType
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Views

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = Constants.spacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let nameCard = AppView.card()
    private let cardNameTextField = CardSetViewController.makeTextField(
        placeholder: "例如：玉山熊本熊", accessibilityLabel: "信用卡名稱"
    )

    /// 每個方案一張卡片，方案增減或加碼開關切換時整組重建。
    private let plansStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = Constants.spacing
        return stackView
    }()

    /// 綠色背景上用白色字，淡綠底的次要按鈕會像停用。
    private let addPlanButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "plus.circle")
        configuration.imagePadding = AppStyle.Spacing.tight
        configuration.attributedTitle = AttributedString(
            "新增方案（可切換權益的卡）", attributes: AttributeContainer([.font: AppStyle.Font.label])
        )
        configuration.baseForegroundColor = AppColor.accent
        return UIButton(configuration: configuration)
    }()

    private let addButton: UIButton

    // MARK: - Init

    init(viewModel: CardSetViewModelType) {
        self.viewModel = viewModel
        self.addButton = AppView.primaryButton(title: viewModel.output.confirmTitle)
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
        title = viewModel.output.title
        cardNameTextField.text = viewModel.output.prefillName
        view.backgroundColor = AppColor.brand
        addTapToDismissKeyboard()

        AppView.cardStack(in: nameCard).addArrangedSubview(Self.titled("信用卡名稱", field: cardNameTextField))

        [nameCard, plansStackView, addPlanButton, addButton].forEach(contentStackView.addArrangedSubview)
        contentStackView.setCustomSpacing(AppStyle.Spacing.tight, after: plansStackView)

        scrollView.addSubview(contentStackView)
        view.addSubview(scrollView)

        cardNameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        addPlanButton.addTarget(self, action: #selector(addPlanTapped), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        if onSkip != nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "略過", style: .plain, target: self, action: #selector(skipTapped)
            )
        }
    }

    private func setupConstraints() {
        let content = scrollView.contentLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // 表單可能比畫面長，鍵盤出現時可視範圍縮到鍵盤上緣，下方欄位可以捲出來。
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            // 內容區要有寬度，否則 contentSize.width 為 0，捲動計算會失效。
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentStackView.topAnchor.constraint(equalTo: content.topAnchor, constant: AppStyle.Spacing.loose),
            contentStackView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Constants.spacing),
            contentStackView.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Constants.horizontalInset
            ),
            contentStackView.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Constants.horizontalInset
            ),

            cardNameTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.fieldHeight)
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.planForms
            .receive(on: DispatchQueue.main)
            .sink { [weak self] forms in
                self?.rebuildPlanCards(with: forms)
            }
            .store(in: &cancellables)

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

        viewModel.output.didSave
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.onFinish?()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func nameChanged() {
        viewModel.input.nameChanged(cardNameTextField.text ?? "")
    }

    @objc private func addPlanTapped() {
        view.endEditing(true)
        viewModel.input.addPlanTapped()
    }

    @objc private func addTapped() {
        view.endEditing(true)
        viewModel.input.addTapped()
    }

    @objc private func skipTapped() {
        view.endEditing(true)
        onSkip?()
    }

    // MARK: - Plan Cards

    private func rebuildPlanCards(with forms: [CardPlanForm]) {
        plansStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        forms.enumerated().forEach { index, form in
            plansStackView.addArrangedSubview(makePlanCard(form, index: index))
        }
    }

    private func makePlanCard(_ form: CardPlanForm, index: Int) -> UIView {
        let card = AppView.card()
        let stack = AppView.cardStack(in: card, spacing: AppStyle.Spacing.tight + 4)

        if form.showsName {
            let title = AppView.label("方案 \(index + 1)", font: AppStyle.Font.labelEmphasis)
            let remove = AppView.plainButton(title: "移除")
            remove.isHidden = !form.canRemove
            remove.setContentHuggingPriority(.required, for: .horizontal)
            remove.addAction(UIAction { [weak self] _ in
                self?.view.endEditing(true)
                self?.viewModel.input.removePlan(at: index)
            }, for: .touchUpInside)
            let header = UIStackView(arrangedSubviews: [title, remove])
            header.alignment = .center
            stack.addArrangedSubview(header)
            stack.addArrangedSubview(makeField(.name, title: "方案名稱", placeholder: "例如：玩旅刷", form: form, index: index))
        }

        stack.addArrangedSubview(
            makeField(.baseRate, title: "基本回饋（%）", placeholder: "例如 3.3", keyboard: .decimalPad, form: form, index: index)
        )
        stack.addArrangedSubview(
            makeField(.baseCap, title: "基本回饋上限（元）", placeholder: "留白為無上限", keyboard: .decimalPad, form: form, index: index)
        )
        stack.addArrangedSubview(makePeriodPicker(.base, selected: form.baseCapPeriod, index: index))
        if form.closingDayTier == .base {
            stack.addArrangedSubview(makeClosingDayField())
        }
        stack.addArrangedSubview(makeBonusSwitchRow(isOn: form.hasBonus, index: index))

        if form.hasBonus {
            stack.addArrangedSubview(
                makeField(.bonusRate, title: "加碼（%）", placeholder: "例如 6", keyboard: .decimalPad, form: form, index: index)
            )
            stack.addArrangedSubview(
                makeField(.bonusCap, title: "加碼上限（元）", placeholder: "留白為無上限", keyboard: .decimalPad, form: form, index: index)
            )
            stack.addArrangedSubview(makePeriodPicker(.bonus, selected: form.bonusCapPeriod, index: index))
            if form.closingDayTier == .bonus {
                stack.addArrangedSubview(makeClosingDayField())
            }
            stack.addArrangedSubview(
                makeField(.bonusLabel, title: "加碼條件", placeholder: "例如：指定店家", form: form, index: index)
            )
        }

        stack.addArrangedSubview(makeDateField(.validFrom, title: "回饋開始日", date: form.validFrom, index: index))
        stack.addArrangedSubview(makeDateField(.validUntil, title: "回饋結束日", date: form.validUntil, index: index))
        stack.addArrangedSubview(makeField(.note, title: "備註", placeholder: "選填，例如：需切換方案", form: form, index: index))
        return card
    }

    /// 欄位上方一定有標題：填了數字之後提示文字就消失，只剩「3.5」「500」會看不出是什麼。
    private func makeField(
        _ field: CardPlanField,
        title: String,
        placeholder: String,
        keyboard: UIKeyboardType = .default,
        form: CardPlanForm,
        index: Int
    ) -> UIView {
        let textField = Self.makeTextField(placeholder: placeholder, accessibilityLabel: title, keyboardType: keyboard)
        textField.text = form.values[field]
        textField.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.fieldHeight).isActive = true
        textField.addAction(UIAction { [weak self, weak textField] _ in
            self?.viewModel.input.planFieldChanged(field, at: index, text: textField?.text ?? "")
        }, for: .editingChanged)
        return Self.titled(title, field: textField)
    }

    private static func titled(_ title: String, field: UIView) -> UIView {
        let label = AppView.label(title, font: AppStyle.Font.label, color: AppColor.textSecondary)
        let stack = UIStackView(arrangedSubviews: [label, field])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    /// 日期用滾輪選，鍵盤上方有「清除」與「完成」；留白代表不限。
    private func makeDateField(_ field: PlanDateField, title: String, date: Date?, index: Int) -> UIView {
        let textField = Self.makeTextField(placeholder: "留白為不限", accessibilityLabel: title)
        textField.text = viewModel.output.dateText(date)
        textField.tintColor = .clear
        textField.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.fieldHeight).isActive = true

        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = Locale(identifier: "zh_TW")
        if let date {
            picker.date = date
        }
        textField.inputView = picker

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let clear = UIBarButtonItem(title: "清除", primaryAction: UIAction { [weak self, weak textField] _ in
            textField?.text = ""
            self?.viewModel.input.planDateChanged(field, at: index, date: nil)
            textField?.resignFirstResponder()
        })
        let done = UIBarButtonItem(title: "完成", primaryAction: UIAction { [weak self, weak textField, weak picker] _ in
            guard let self, let picker else { return }
            textField?.text = self.viewModel.output.dateText(picker.date)
            self.viewModel.input.planDateChanged(field, at: index, date: picker.date)
            textField?.resignFirstResponder()
        })
        toolbar.items = [clear, UIBarButtonItem(systemItem: .flexibleSpace), done]
        textField.inputAccessoryView = toolbar

        return Self.titled(title, field: textField)
    }

    /// 帳單結帳日，緊接在選了「每期帳單」的週期選項下方，使用者一選就看得到要填什麼。
    /// 整張卡共用一個值，所以只出現一次。
    private func makeClosingDayField() -> UIView {
        let textField = Self.makeTextField(
            placeholder: "每月幾號，例如 15", accessibilityLabel: "帳單結帳日", keyboardType: .numberPad
        )
        textField.text = viewModel.output.closingDayText
        textField.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.fieldHeight).isActive = true
        textField.addAction(UIAction { [weak self, weak textField] _ in
            self?.viewModel.input.closingDayChanged(textField?.text ?? "")
        }, for: .editingChanged)

        let hint = AppView.label(
            "同一張卡的方案共用，可在帳單或銀行 App 查到",
            font: AppStyle.Font.caption,
            color: AppColor.textSecondary
        )
        let stack = UIStackView(arrangedSubviews: [Self.titled("帳單結帳日", field: textField), hint])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    /// 上限多久重新計算。沒有填上限時選了也不影響計算。
    private func makePeriodPicker(_ tier: CapTier, selected: CapPeriod, index: Int) -> UIView {
        let periods = CapPeriod.allCases
        let control = AppView.segmentedControl(items: periods.map(\.title))
        control.selectedSegmentIndex = periods.firstIndex(of: selected) ?? 0
        control.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
        control.addAction(UIAction { [weak self, weak control] _ in
            guard let control, periods.indices.contains(control.selectedSegmentIndex) else { return }
            self?.viewModel.input.capPeriodChanged(tier, at: index, period: periods[control.selectedSegmentIndex])
        }, for: .valueChanged)
        return Self.titled(tier == .base ? "上限計算週期" : "加碼上限計算週期", field: control)
    }

    private func makeBonusSwitchRow(isOn: Bool, index: Int) -> UIView {
        let label = AppView.label("有加碼回饋", font: AppStyle.Font.body)
        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.onTintColor = AppColor.accent
        toggle.accessibilityLabel = "有加碼回饋"
        toggle.addAction(UIAction { [weak self, weak toggle] _ in
            self?.view.endEditing(true)
            self?.viewModel.input.bonusToggled(at: index, isOn: toggle?.isOn ?? false)
        }, for: .valueChanged)
        let row = UIStackView(arrangedSubviews: [label, toggle])
        row.alignment = .center
        return row
    }

    // MARK: - Private

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    private static func makeTextField(
        placeholder: String,
        accessibilityLabel: String,
        keyboardType: UIKeyboardType = .default
    ) -> UITextField {
        let textField = AppView.textField(keyboardType: keyboardType)
        textField.placeholder = placeholder
        textField.accessibilityLabel = accessibilityLabel
        return textField
    }
}
