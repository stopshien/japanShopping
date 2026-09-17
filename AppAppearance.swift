//
//  AppAppearance.swift
//  japanShopping
//

import UIKit

/// 導航列外觀。集中設定，避免各畫面各自調整而不一致。
enum ComputeAppearance {

    static func apply(to navigationBar: UINavigationBar) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColor.brand
        appearance.shadowColor = AppColor.separator
        appearance.titleTextAttributes = [
            .foregroundColor: AppColor.textPrimary,
            .font: AppStyle.Font.bodyEmphasis
        ]

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = AppColor.accent
    }
}
