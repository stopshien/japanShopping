//
//  TripContentStore.swift
//  japanShopping
//

import Foundation

/// 專案內容（購物清單與其中的照片）的存取與清除。
/// 把「檔名怎麼取」集中在這裡，其他地方只認 Trip 的 id。
protocol TripContentStore {
    func shoppingListRepository(for tripID: UUID) -> ShoppingListRepository
    /// 刪除專案時一併清掉它的清單檔與照片，不留孤兒檔案。
    func removeContent(of tripID: UUID)
}

final class FileTripContentStore: TripContentStore {

    private let imageStore: ImageStore

    init(imageStore: ImageStore = FileImageStore()) {
        self.imageStore = imageStore
    }

    static func fileName(for tripID: UUID) -> String {
        "list-\(tripID.uuidString)"
    }

    func shoppingListRepository(for tripID: UUID) -> ShoppingListRepository {
        FileShoppingListRepository(
            fileURL: DocumentsDirectory.fileURL(named: Self.fileName(for: tripID))
        )
    }

    func removeContent(of tripID: UUID) {
        let repository = shoppingListRepository(for: tripID)
        let items = (try? repository.load()) ?? []
        items.compactMap(\.photoURL).forEach { try? imageStore.remove(named: $0) }

        let fileURL = DocumentsDirectory.fileURL(named: Self.fileName(for: tripID))
        try? FileManager.default.removeItem(at: fileURL)
    }
}
