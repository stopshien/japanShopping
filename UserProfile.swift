//
//  UserProfile.swift
//  japanShopping
//

import Foundation

/// 使用者的基本設定，於首次啟動的引導流程建立，之後可在設定頁修改。
struct UserProfile: Codable, Equatable {
    var name: String
    var currency: Currency
}
