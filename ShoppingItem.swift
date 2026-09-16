//
//  ShoppingItem.swift
//  japanShopping
//
//  原本名為 List，遷移時改為更明確的名稱。
//  屬性名稱不可更動：存檔是 property list，欄位名就是既有使用者資料的鍵。
//

import Foundation

struct ShoppingItem: Codable, Equatable {
    var productName: String
    var price: Double
    var payType: String
    var taxState: String
    var photoURL: String?
}
