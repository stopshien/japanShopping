//
//  CardRepository.swift
//  japanShopping
//

import Foundation

protocol CardRepository {
    func load() throws -> [Card]
    func save(_ cards: [Card]) throws
}

/// 以 property list 形式存放在 Documents 目錄下的 "cards" 檔案。
/// 檔名與編碼方式必須與遷移前一致，否則使用者既有的存檔會讀不回來。
final class FileCardRepository: CardRepository {

    private enum Constants {
        static let fileName = "cards"
    }

    private let fileURL: URL

    init(fileURL: URL = DocumentsDirectory.fileURL(named: Constants.fileName)) {
        self.fileURL = fileURL
    }

    func load() throws -> [Card] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try PropertyListDecoder().decode([Card].self, from: data)
    }

    func save(_ cards: [Card]) throws {
        let data = try PropertyListEncoder().encode(cards)
        try data.write(to: fileURL)
    }
}
