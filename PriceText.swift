//
//  PriceText.swift
//  japanShopping
//

import Foundation

/// 金額顯示格式的單一來源。
///
/// 不顯示多餘的小數位（206 而非 206.0），但保留真正存在的角分（4995.88）。
/// 不使用千分位分隔符。
enum PriceText {

    private enum Constants {
        static let maximumFractionDigits = 2
    }

    /// 固定語系，讓輸出不隨裝置設定改變（小數點一律是 "."）。
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = Constants.maximumFractionDigits
        formatter.roundingMode = .halfUp
        return formatter
    }()

    static func amount(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
