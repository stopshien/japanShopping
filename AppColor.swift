//
//  AppColor.swift
//  japanShopping
//

import UIKit

/// 專案共用色票。
///
/// 每組前景／背景的搭配都通過 WCAG AA（對比度 ≥ 4.5），
/// 因為這個 App 的使用場景是在戶外商店街看手機。
/// 調整任一顏色前請先確認對比度仍達標。
enum AppColor {

    /// 主視覺的橄欖綠，用於畫面底色。
    static let brand = UIColor(displayP3Red: 0.7567, green: 0.7892, blue: 0.5646, alpha: 1)

    /// 卡片與輸入區的底色。
    static let surface = UIColor.white

    /// 主要文字。在 brand 上對比 8.47、在 surface 上 14.76。
    static let textPrimary = UIColor(displayP3Red: 0.13, green: 0.17, blue: 0.06, alpha: 1)

    /// 次要文字（說明、時間戳）。在 brand 上對比 4.62、在 surface 上 8.06。
    static let textSecondary = UIColor(displayP3Red: 0.29, green: 0.33, blue: 0.19, alpha: 1)

    /// 強調色，用於主要按鈕底色與可點擊文字。白字在其上對比 9.11。
    static let accent = UIColor(displayP3Red: 0.22, green: 0.31, blue: 0.11, alpha: 1)

    /// 次要按鈕的底色。疊在白色卡片上仍看得出是可點擊區域。
    static let accentSoft = UIColor(displayP3Red: 0.22, green: 0.31, blue: 0.11, alpha: 0.12)

    /// 卡片與控制項的分隔線。
    static let separator = UIColor(displayP3Red: 0.13, green: 0.17, blue: 0.06, alpha: 0.12)
}
