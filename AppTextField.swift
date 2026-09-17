//
//  AppTextField.swift
//  japanShopping
//

import UIKit

/// 提示文字用固定顏色的輸入框。
///
/// 系統的 placeholder 顏色會隨深色模式改變，但本專案的底色是寫死的淺色，
/// 兩者湊在一起會讓提示文字在深色模式下幾乎看不見。
/// 這裡攔截 placeholder 的設定，一律套上 `AppColor.placeholder`；
/// 用 didSet 而非只在建立時設定，是因為換算頁的提示文字會隨幣別在執行期改變。
final class AppTextField: UITextField {

    private var isApplyingStyle = false

    override var placeholder: String? {
        didSet { applyPlaceholderStyle() }
    }

    private func applyPlaceholderStyle() {
        guard !isApplyingStyle else { return }
        isApplyingStyle = true
        defer { isApplyingStyle = false }

        guard let placeholder else {
            attributedPlaceholder = nil
            return
        }
        attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: AppColor.placeholder]
        )
    }
}
