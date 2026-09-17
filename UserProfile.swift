//
//  UserProfile.swift
//  japanShopping
//

import Foundation

/// 使用者的基本資料。目前只有稱呼，之後要擴充再加欄位。
struct UserProfile: Codable, Equatable {
    var name: String
}
