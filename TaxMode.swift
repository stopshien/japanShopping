//
//  TaxMode.swift
//  japanShopping
//

import Foundation

/// 日本消費稅的換算模式。
enum TaxMode: Int, CaseIterable {

    /// 輸入的是未稅價
    case excludingTax = 0
    /// 輸入的是含稅價
    case includingTax = 1

    static let taxMultiplier = 1.08

    var title: String {
        switch self {
        case .excludingTax:
            return "未稅"
        case .includingTax:
            return "含稅"
        }
    }
}

/// 一筆日圓價格換算後的台幣結果。
struct PriceBreakdown: Equatable {

    let untaxed: Double
    let taxed: Double

    init(yen: Double, rate: Double, mode: TaxMode) {
        switch mode {
        case .excludingTax:
            let untaxed = (yen * rate).rounded()
            self.untaxed = untaxed
            self.taxed = (untaxed * TaxMode.taxMultiplier).rounded()
        case .includingTax:
            let taxed = (yen * rate).rounded()
            self.taxed = taxed
            self.untaxed = (taxed / TaxMode.taxMultiplier).rounded()
        }
    }
}
