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

    /// 字級全部跟著系統的「文字大小」設定縮放。
    ///
    /// 這個 App 是在店裡、戶外光線下看數字，放大字體的需求比一般 App 高。
    /// 金額的大字有上限，否則最大字級下 NT$ 1,280,000 會排不下。
    enum Font {
        static let title = scaled(.systemFont(ofSize: 28, weight: .semibold), as: .title1, maximum: 40)
        /// 金額用等寬數字，打字或結果變動時數字不會左右跳動。
        static let resultNumber = scaled(
            .monospacedDigitSystemFont(ofSize: 40, weight: .bold), as: .largeTitle, maximum: 52
        )
        /// 清單列的金額，等寬數字讓上下兩列的位數對得齊。
        static let amountRow = scaled(
            .monospacedDigitSystemFont(ofSize: 17, weight: .semibold), as: .body, maximum: 30
        )
        static let amountInput = scaled(
            .monospacedDigitSystemFont(ofSize: 30, weight: .semibold), as: .title2, maximum: 40
        )
        static let body = scaled(.systemFont(ofSize: 17), as: .body, maximum: 30)
        static let bodyEmphasis = scaled(.systemFont(ofSize: 17, weight: .semibold), as: .body, maximum: 30)
        static let label = scaled(.systemFont(ofSize: 15, weight: .medium), as: .subheadline, maximum: 26)
        static let caption = scaled(.systemFont(ofSize: 13), as: .caption1, maximum: 22)

        private static func scaled(_ font: UIFont, as style: UIFont.TextStyle, maximum: CGFloat) -> UIFont {
            UIFontMetrics(forTextStyle: style).scaledFont(for: font, maximumPointSize: maximum)
        }
    }
}
