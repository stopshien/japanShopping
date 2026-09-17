//
//  UserProfileRepository.swift
//  japanShopping
//

import Foundation

protocol UserProfileRepository {
    func load() -> UserProfile?
    func save(_ profile: UserProfile) throws
}

/// 使用者稱呼存在 UserDefaults，而不是像購物清單那樣存成 property list 檔案。
///
/// 購物清單與信用卡是會成長的資料集合，值得一個檔案；
/// 稱呼是單一設定值，UserDefaults 才是它該待的地方。
final class UserDefaultsUserProfileRepository: UserProfileRepository {

    private enum Constants {
        static let key = "userProfile"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UserProfile? {
        guard let data = defaults.data(forKey: Constants.key) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    func save(_ profile: UserProfile) throws {
        let data = try JSONEncoder().encode(profile)
        defaults.set(data, forKey: Constants.key)
    }
}
