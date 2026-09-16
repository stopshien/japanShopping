//
//  ShoppingListRepository.swift
//  japanShopping
//

import Foundation

protocol ShoppingListRepository {
    func load() throws -> [ShoppingItem]
    func save(_ items: [ShoppingItem]) throws
}

/// 以 property list 形式存放在 Documents 目錄下的 "list" 檔案。
/// 檔名與編碼方式必須與遷移前一致，否則使用者既有的清單會讀不回來。
final class FileShoppingListRepository: ShoppingListRepository {

    private enum Constants {
        static let fileName = "list"
    }

    private let fileURL: URL

    init(fileURL: URL = DocumentsDirectory.fileURL(named: Constants.fileName)) {
        self.fileURL = fileURL
    }

    func load() throws -> [ShoppingItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try PropertyListDecoder().decode([ShoppingItem].self, from: data)
    }

    func save(_ items: [ShoppingItem]) throws {
        let data = try PropertyListEncoder().encode(items)
        try data.write(to: fileURL)
    }
}
