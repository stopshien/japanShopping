//
//  Currency.swift
//  japanShopping
//

import Foundation

/// 商品的稅率類別。
///
/// 日本自 2019 年起採雙稅率：食品飲料適用 8% 的輕減稅率，其餘 10%。
/// 酒類與內用餐飲雖然是飲食，仍適用 10%，因此這個選擇必須由使用者指定，
/// App 無法從價格或名稱推斷。
enum TaxCategory: Int, CaseIterable {

    case standard = 0
    case reducedFood = 1

    var title: String {
        switch self {
        case .standard:
            return "一般"
        case .reducedFood:
            return "食品"
        }
    }
}

/// 可換算的外幣。稅率隨國別走。
enum Currency: Int, CaseIterable, Codable {

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

    /// 該國是否有輕減稅率。沒有的話就不需要讓使用者選類別。
    var hasReducedTaxRate: Bool {
        TaxCategory.allCases.map(taxMultiplier(for:)).uniqueCount > 1
    }

    /// 該國消費稅／加值稅的乘數。
    func taxMultiplier(for category: TaxCategory) -> Double {
        switch self {
        case .japaneseYen:
            switch category {
            case .standard:
                return 1.1
            case .reducedFood:
                return 1.08
            }
        case .koreanWon:
            // 韓國加值稅為單一稅率，不區分商品類別。
            return 1.1
        }
    }

    /// 稅率百分比，供畫面顯示（例如 10）。
    func taxPercent(for category: TaxCategory) -> Int {
        Int(((taxMultiplier(for: category) - 1) * 100).rounded())
    }
}

private extension Array where Element: Hashable {
    var uniqueCount: Int { Set(self).count }
}
