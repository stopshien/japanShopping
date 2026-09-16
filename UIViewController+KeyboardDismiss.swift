//
//  UIViewController+KeyboardDismiss.swift
//  japanShopping
//

import UIKit

extension UIViewController {

    /// 點擊空白處收鍵盤。各畫面共用同一份實作，不要各自重建 gesture。
    func addTapToDismissKeyboard() {
        let tapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
}
