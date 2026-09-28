//
//  FeedbackLedgerRepository.swift
//  japanShopping
//

import Foundation

/// 回饋明細的存取。所有旅程共用一份，卡片也是跨旅程共用的。
protocol FeedbackLedgerRepository {
    func load() throws -> [FeedbackEntry]
    func save(_ entries: [FeedbackEntry]) throws
}

/// 以 property list 形式存放在 Documents 目錄下的 "cardFeedback" 檔案。
final class FileFeedbackLedgerRepository: FeedbackLedgerRepository {

    private enum Constants {
        static let fileName = "cardFeedback"
    }

    private let fileURL: URL

    init(fileURL: URL = DocumentsDirectory.fileURL(named: Constants.fileName)) {
        self.fileURL = fileURL
    }

    func load() throws -> [FeedbackEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try PropertyListDecoder().decode([FeedbackEntry].self, from: data)
    }

    func save(_ entries: [FeedbackEntry]) throws {
        let data = try PropertyListEncoder().encode(entries)
        try data.write(to: fileURL)
    }
}
