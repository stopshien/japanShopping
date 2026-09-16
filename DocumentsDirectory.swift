//
//  DocumentsDirectory.swift
//  japanShopping
//

import Foundation

/// 全專案唯一解析 Documents 目錄的地方。
/// 其他型別一律透過這裡取得路徑，不要各自呼叫 FileManager。
enum DocumentsDirectory {

    static let url: URL = {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            preconditionFailure("Documents directory is always available on iOS")
        }
        return url
    }()

    static func fileURL(named name: String) -> URL {
        url.appendingPathComponent(name)
    }
}
