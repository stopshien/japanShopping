//
//  Card.swift
//  japanShopping
//

import Foundation

/// 信用卡資料。純資料型別，存取邏輯由 CardRepository 負責。
struct Card: Codable, Equatable {
    let name: String
    let percent: Double
    let limit: Double
    var feedbackMoney = 0.0
    var feedbackRemaining = 0.0
}
