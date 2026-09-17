//
//  Currency.swift
//  japanShopping
//

import Foundation

/// 可換算的外幣。稅率隨國別走，不另外讓使用者選。
enum Currency: Int, CaseIterable {

    case japaneseYen = 0
    case koreanWon = 1

    var title: String {
        switch self {
        case .japaneseYen:
            return "日幣"
        case .koreanWon:
            return "韓幣"
        }
    }

    var inputPlaceholder: String {
        "請輸入\(title)價格..."
    }

    /// 該國消費稅／加值稅的乘數。
    /// 日本一般商品自 2019 年起為 10%（食品飲料另有 8% 的輕減稅率，本 App 不套用）；
    /// 韓國加值稅同為 10%。
    var taxMultiplier: Double {
        switch self {
        case .japaneseYen:
            return 1.1
        case .koreanWon:
            return 1.1
        }
    }
}
