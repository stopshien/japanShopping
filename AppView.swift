//
//  AppView.swift
//  japanShopping
//

import UIKit

/// 共用的視覺元件工廠。
/// 按鈕分為三級，讓使用者一眼看得出哪個是主要動作。
enum AppView {

    /// 主要動作：實心底色。每個畫面至多一個。
    static func primaryButton(title: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = AppColor.accent
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = AppStyle.Radius.control
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 14, leading: AppStyle.Spacing.normal,
            bottom: 14, trailing: AppStyle.Spacing.normal
        )
        configuration.attributedTitle = AttributedString(
            title, attributes: AttributeContainer([.font: AppStyle.Font.bodyEmphasis])
        )
        return make(configuration)
    }

    /// 次要動作：淡色底、強調色文字。
    /// 不能用白底 —— 次要按鈕多半放在白色卡片內，白底會讓它看起來像純文字。
    static func secondaryButton(title: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = AppColor.accentSoft
        configuration.baseForegroundColor = AppColor.accent
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = AppStyle.Radius.control
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12, leading: AppStyle.Spacing.normal,
            bottom: 12, trailing: AppStyle.Spacing.normal
        )
        configuration.attributedTitle = AttributedString(
            title, attributes: AttributeContainer([.font: AppStyle.Font.body])
        )
        return make(configuration)
    }

    /// 次要按鈕的第二行說明。空字串時只顯示主要文字。
    static func setSubtitle(_ subtitle: String, on button: UIButton) {
        button.configuration?.attributedSubtitle = subtitle.isEmpty ? nil : AttributedString(
            subtitle, attributes: AttributeContainer([.font: AppStyle.Font.caption])
        )
    }

    /// 第三級：純文字，不搶視覺。
    static func plainButton(title: String) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.baseForegroundColor = AppColor.accent
        configuration.attributedTitle = AttributedString(
            title, attributes: AttributeContainer([.font: AppStyle.Font.body])
        )
        return make(configuration)
    }

    /// 導航列上的圖示按鈕。一定要給 accessibilityLabel，
    /// 否則 VoiceOver 只會唸出符號名稱。
    static func barButton(
        systemImage: String,
        accessibilityLabel: String,
        target: Any?,
        action: Selector
    ) -> UIBarButtonItem {
        let item = UIBarButtonItem(
            image: UIImage(systemName: systemImage),
            style: .plain,
            target: target,
            action: action
        )
        item.accessibilityLabel = accessibilityLabel
        item.tintColor = AppColor.accent
        return item
    }

    /// 白色圓角卡片，用來把相關的控制項框在一起。
    static func card() -> UIView {
        let view = UIView()
        view.backgroundColor = AppColor.surface
        view.layer.cornerRadius = AppStyle.Radius.card
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    /// 卡片內的垂直堆疊，已套好內側留白。
    static func cardStack(in card: UIView, spacing: CGFloat = AppStyle.Spacing.normal) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = spacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stackView)
        let inset = AppStyle.Spacing.cardInset
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: inset),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -inset)
        ])
        return stackView
    }

    static func label(
        _ text: String? = nil,
        font: UIFont = AppStyle.Font.body,
        color: UIColor = AppColor.textPrimary,
        alignment: NSTextAlignment = .natural
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.textAlignment = alignment
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func textField(keyboardType: UIKeyboardType = .default) -> UITextField {
        let textField = AppTextField()
        textField.font = AppStyle.Font.body
        textField.textColor = AppColor.textPrimary
        textField.keyboardType = keyboardType
        textField.backgroundColor = AppColor.surface
        textField.layer.cornerRadius = AppStyle.Radius.control
        textField.layer.borderWidth = 1
        textField.layer.borderColor = AppColor.separator.cgColor
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: AppStyle.Spacing.normal, height: 0))
        textField.leftViewMode = .always
        textField.adjustsFontForContentSizeCategory = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }

    static func segmentedControl(items: [String]) -> UISegmentedControl {
        let control = UISegmentedControl(items: items)
        control.selectedSegmentTintColor = AppColor.accent
        control.backgroundColor = AppColor.surface
        control.setTitleTextAttributes(
            [.foregroundColor: AppColor.textPrimary, .font: AppStyle.Font.label], for: .normal
        )
        control.setTitleTextAttributes(
            [.foregroundColor: UIColor.white, .font: AppStyle.Font.label], for: .selected
        )
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }

    /// 按鈕的字也要跟著字級縮放；放不下時換行，不要截斷金額。
    private static func make(_ configuration: UIButton.Configuration) -> UIButton {
        var configuration = configuration
        configuration.titleLineBreakMode = .byWordWrapping
        let button = UIButton(configuration: configuration)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}
