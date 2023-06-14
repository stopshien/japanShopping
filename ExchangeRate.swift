//
//  ExchangeRate.swift
//  japanShopping
//
//  Created by 沈庭鋒 on 2023/6/14.
//

import Foundation

struct ExchangeRate : Codable{
    let time_last_update_utc : String
    let conversion_rates : Rates
}

struct Rates : Codable{
    
    let USD : Double
    let JPY : Double
    let TWD : Double
}
