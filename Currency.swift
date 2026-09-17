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
    /// 日本 8% 是食品飲料的輕減稅率；韓國加值稅為 10%。
    var taxMultiplier: Double {
        switch self {
        case .japaneseYen:
            return 1.08
        case .koreanWon:
            return 1.1
        }
    }
}
