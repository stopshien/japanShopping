//
//  ExchangeRate.swift
//  japanShopping
//

import Foundation

/// exchangerate-api.com 的回應。
/// 屬性名依 Swift 慣例命名，對應的 JSON 鍵由 CodingKeys 指定。
struct ExchangeRate: Codable, Equatable {

    let lastUpdatedUTC: String
    let conversionRates: ConversionRates

    enum CodingKeys: String, CodingKey {
        case lastUpdatedUTC = "time_last_update_utc"
        case conversionRates = "conversion_rates"
    }

    /// 日圓兌台幣。API 以美金為基準，因此由 TWD / JPY 推導。
    var yenToTaiwanDollar: Double {
        let raw = conversionRates.twd / conversionRates.jpy
        return (raw * 10000).rounded() / 10000
    }
}

struct ConversionRates: Codable, Equatable {

    let usd: Double
    let jpy: Double
    let twd: Double

    enum CodingKeys: String, CodingKey {
        case usd = "USD"
        case jpy = "JPY"
        case twd = "TWD"
    }
}
