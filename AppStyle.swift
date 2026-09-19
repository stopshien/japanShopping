//
//  AppStyle.swift
//  japanShopping
//

import UIKit

/// 間距、圓角與字級的單一來源。
/// 數值取自 8pt 級距，避免每個畫面各自決定間距而失去一致性。
enum AppStyle {

    enum Spacing {
        static let tight: CGFloat = 8
        static let normal: CGFloat = 16
        static let loose: CGFloat = 24
        /// 卡片內側留白
        static let cardInset: CGFloat = 16
    }

    enum Radius {
        static let control: CGFloat = 12
        static let card: CGFloat = 16
    }

    enum Font {
        static let title = UIFont.systemFont(ofSize: 28, weight: .semibold)
        /// 金額用等寬數字，打字或結果變動時數字不會左右跳動。
        static let resultNumber = UIFont.monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        static let amountInput = UIFont.monospacedDigitSystemFont(ofSize: 30, weight: .semibold)
        static let body = UIFont.systemFont(ofSize: 17)
        static let bodyEmphasis = UIFont.systemFont(ofSize: 17, weight: .semibold)
        static let label = UIFont.systemFont(ofSize: 15, weight: .medium)
        static let caption = UIFont.systemFont(ofSize: 13)
    }
}
