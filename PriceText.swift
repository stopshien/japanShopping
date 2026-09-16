//
//  PriceText.swift
//  japanShopping
//

import Foundation

/// 金額顯示格式的單一來源。
///
/// 目前沿用遷移前的輸出（直接內插 Double，例如 206.0），
/// 讓已遷移與未遷移的畫面看起來一致。等 Compute 與 Detail 也遷移完成後，
/// 只要改這裡就能一次調整全專案的金額格式。
enum PriceText {

    static func amount(_ value: Double) -> String {
        "\(value)"
    }
}
