//
//  PriceText.swift
//  japanShopping
//

import Foundation

/// 金額顯示格式的單一來源。
///
/// 不顯示多餘的小數位（206 而非 206.0），但保留真正存在的角分（4995.88）。
/// `amount` 不使用千分位分隔符，給清單與明細使用；
/// 首頁的大字金額用 `twd` 與 `groupedInput`，加上千分位方便一眼讀出位數。
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

    private static let groupedFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = Constants.maximumFractionDigits
        formatter.roundingMode = .halfUp
        return formatter
    }()

    static func amount(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// 台幣金額，帶千分位，例如「NT$ 1,254」。
    static func twd(_ value: Double) -> String {
        "NT$ \(groupedFormatter.string(from: NSNumber(value: value)) ?? "\(value)")"
    }

    /// 給 VoiceOver 念的台幣金額，例如「台幣 1,254 元」。
    /// 「NT$」會被逐字念成「N T 錢字號」。
    static func twdSpoken(_ value: Double) -> String {
        "台幣 \(groupedFormatter.string(from: NSNumber(value: value)) ?? "\(value)") 元"
    }

    /// 輸入中的金額加上千分位。小數部分照使用者打的保留（「1000.」要留著小數點），
    /// 整數部分不是純數字時回傳 nil，由呼叫端維持原本的文字。
    static func groupedInput(_ raw: String) -> String? {
        let parts = raw.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let integerPart = String(parts[0])
        guard !integerPart.isEmpty, integerPart.allSatisfy(\.isASCIIDigit),
              let integer = Double(integerPart),
              let grouped = groupedFormatter.string(from: NSNumber(value: integer)) else { return nil }
        return parts.count > 1 ? "\(grouped).\(parts[1])" : grouped
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
