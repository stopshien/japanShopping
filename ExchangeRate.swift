//
//  ExchangeRate.swift
//  japanShopping
//

import Foundation

/// exchangerate-api.com 免金鑰端點的回應。
/// 屬性名依 Swift 慣例命名，對應的 JSON 鍵由 CodingKeys 指定。
struct ExchangeRate: Codable, Equatable {

    private enum Constants {
        /// 匯率保留的有效位數。
        ///
        /// 不能改用「小數第幾位」：日幣兌台幣約 0.2 而韓幣約 0.023，
        /// 同樣取到小數第 4 位時，韓幣只剩 3 位有效數字，誤差會放大到 0.2%。
        static let significantDigits = 4
    }

    let lastUpdatedUTC: String
    let conversionRates: ConversionRates

    enum CodingKeys: String, CodingKey {
        case lastUpdatedUTC = "time_last_update_utc"
        case conversionRates = "rates"
    }

    /// 外幣兌台幣。API 以美金為基準，因此由 TWD / 外幣 推導。
    func rateToTaiwanDollar(for currency: Currency) -> Double {
        let foreignRate: Double
        switch currency {
        case .japaneseYen:
            foreignRate = conversionRates.jpy
        case .koreanWon:
            foreignRate = conversionRates.krw
        }
        guard foreignRate > 0 else { return 0 }
        return Self.rounded(conversionRates.twd / foreignRate, toSignificantDigits: Constants.significantDigits)
    }

    private static func rounded(_ value: Double, toSignificantDigits digits: Int) -> Double {
        guard value != 0, value.isFinite else { return value }
        let magnitude = floor(log10(abs(value)))
        let factor = pow(10, Double(digits - 1) - magnitude)
        return (value * factor).rounded() / factor
    }
}

struct ConversionRates: Codable, Equatable {

    let usd: Double
    let jpy: Double
    let twd: Double
    let krw: Double

    enum CodingKeys: String, CodingKey {
        case usd = "USD"
        case jpy = "JPY"
        case twd = "TWD"
        case krw = "KRW"
    }
}
