//
//  AppAppearance.swift
//  japanShopping
//

import UIKit

/// 導航列外觀。全 App 共用，由 SceneDelegate 與引導流程各套用一次。
enum AppAppearance {

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
