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

    /// 金額輸入框的名稱，給 VoiceOver 念（畫面上的提示文字只有「0」）。
    var amountLabel: String {
        "\(title)價格"
    }

    /// 輸入框前的幣別符號。
    var symbol: String {
        switch self {
        case .japaneseYen:
            return "¥"
        case .koreanWon:
            return "₩"
        }
    }

    /// ISO 4217 代碼，用於匯率說明（1 JPY = 0.2 TWD）。
    var code: String {
        switch self {
        case .japaneseYen:
            return "JPY"
        case .koreanWon:
            return "KRW"
        }
    }

    /// 旅程標籤前的國旗，讓人一眼認出現在是哪個國家的旅程。
    var flag: String {
        switch self {
        case .japaneseYen:
            return "🇯🇵"
        case .koreanWon:
            return "🇰🇷"
        }
    }

    /// 該國店家是否常見未稅標價。
    ///
    /// 日本自 2021 年起規定標示含稅總價，但「1,000円（税込1,100円）」這種
    /// 未稅價寫得比較大的標法仍很常見，所以保留切換。
    /// 韓國零售標價幾乎都含稅；「부가세 별도」（加值稅另計）多見於飯店與部分餐廳，
    /// 不是這個 App 的購物情境，因此不顯示開關，讓畫面保持簡潔。
    var hasTaxExcludedPriceTags: Bool {
        switch self {
        case .japaneseYen:
            return true
        case .koreanWon:
            return false
        }
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
