//
//  ImageStore.swift
//  japanShopping
//

import Foundation

protocol ImageStore {
    /// 儲存圖片並回傳檔名（不含副檔名）。
    func save(_ data: Data) throws -> String
    func loadData(named filename: String) throws -> Data
    func remove(named filename: String) throws
}

/// 以 UUID 命名的 JPEG，存在 Documents 目錄下。
/// 只保存檔名，不保存絕對路徑：App 容器路徑每次安裝都會變。
final class FileImageStore: ImageStore {

    private enum Constants {
        static let fileExtension = "jpg"
    }

    private let directory: URL

    init(directory: URL = DocumentsDirectory.url) {
        self.directory = directory
    }

    func save(_ data: Data) throws -> String {
        let filename = UUID().uuidString
        try data.write(to: url(for: filename))
        return filename
    }

    func loadData(named filename: String) throws -> Data {
        try Data(contentsOf: url(for: filename))
    }

    func remove(named filename: String) throws {
        let url = url(for: filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename).appendingPathExtension(Constants.fileExtension)
    }
}
