//
//  ApiManager.swift
//  japanShopping
//
//  Created by TingFeng Shen on 2023/10/24.
//

import Foundation
class ApiManager {
    static let shared = ApiManager()
    private init() {}
    let apiKey = Bundle.main.object(forInfoDictionaryKey: "Authorization_KEY") as? String
}
