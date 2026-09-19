//
//  TaxMode.swift
//  japanShopping
//

import Foundation

/// 輸入的價格是未稅還是含稅。
enum TaxMode: Int, CaseIterable {

    /// 輸入的是未稅價
    case excludingTax = 0
    /// 輸入的是含稅價
    case includingTax = 1

    var title: String {
        switch self {
        case .excludingTax:
            return "未稅"
        case .includingTax:
            return "含稅"
        }
    }

    /// 首頁輸入框旁的標註。
    var priceTagLabel: String {
        "\(title)價"
    }
}

/// 一筆外幣價格換算後的台幣結果。
struct PriceBreakdown: Equatable {

    let untaxed: Double
    let taxed: Double

    /// - Parameter taxMultiplier: 由 `Currency.taxMultiplier` 提供，隨幣別對應的國別稅率。
    init(amount: Double, rate: Double, mode: TaxMode, taxMultiplier: Double) {
        switch mode {
        case .excludingTax:
            let untaxed = (amount * rate).rounded()
            self.untaxed = untaxed
            self.taxed = (untaxed * taxMultiplier).rounded()
        case .includingTax:
            let taxed = (amount * rate).rounded()
            self.taxed = taxed
            self.untaxed = (taxed / taxMultiplier).rounded()
        }
    }
}
