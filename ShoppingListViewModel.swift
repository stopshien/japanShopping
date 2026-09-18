//
//  ShoppingListViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

struct ShoppingListItem: Equatable {
    let productName: String
    let priceDescription: String
    let payType: String
    let imageData: Data?
}

/// 要開啟編輯頁的那一筆。
struct ShoppingListEditRequest: Equatable {
    let index: Int
    let item: ShoppingItem
    let photoData: Data?
}

protocol ShoppingListViewModelType {
    var input: ShoppingListViewModelInput { get }
    var output: ShoppingListViewModelOutput { get }
}

protocol ShoppingListViewModelInput {
    func viewDidLoad()
    func deleteItem(at index: Int)
    func itemSelected(at index: Int)
    func itemEdited(at index: Int, _ edit: ItemEdit)
    func doneTapped()
}

protocol ShoppingListViewModelOutput {
    var items: AnyPublisher<[ShoppingListItem], Never> { get }
    var totalSpendText: AnyPublisher<String, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didFinish: AnyPublisher<Void, Never> { get }
    var editRequest: AnyPublisher<ShoppingListEditRequest, Never> { get }
}

// MARK: - ViewModel

final class ShoppingListViewModel: ShoppingListViewModelType {

    /// 清單中的一筆，加上編輯後尚未寫檔的新照片。
    private struct Row {
        var item: ShoppingItem
        var newPhotoData: Data?
    }

    private let repository: ShoppingListRepository
    private let imageStore: ImageStore
    /// 歡迎頁設定的稱呼。沒有設定時總金額就用不帶稱呼的句子。
    private let userName: String?

    private var rows: [Row] = []
    /// 已從清單移除或被新照片取代、待按下 Done 時一併刪除的圖片檔名。
    private var removedPhotoNames: [String] = []

    private let itemsSubject = CurrentValueSubject<[ShoppingListItem], Never>([])
    private let totalSpendTextSubject = CurrentValueSubject<String, Never>("")
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didFinishSubject = PassthroughSubject<Void, Never>()
    private let editRequestSubject = PassthroughSubject<ShoppingListEditRequest, Never>()

    init(
        repository: ShoppingListRepository,
        imageStore: ImageStore,
        userProfileRepository: UserProfileRepository
    ) {
        self.repository = repository
        self.imageStore = imageStore
        self.userName = userProfileRepository.load()?.name
    }

    var input: ShoppingListViewModelInput { self }
    var output: ShoppingListViewModelOutput { self }

    // MARK: - Private

    private func publish() {
        itemsSubject.send(rows.map(makeDisplayItem))
        totalSpendTextSubject.send(makeTotalSpendText())
    }

    private func makeDisplayItem(from row: Row) -> ShoppingListItem {
        ShoppingListItem(
            productName: row.item.productName,
            priceDescription: "\(PriceText.amount(row.item.price))$(\(row.item.taxState))",
            payType: row.item.payType,
            imageData: photoData(for: row)
        )
    }

    private func photoData(for row: Row) -> Data? {
        row.newPhotoData ?? loadImageData(named: row.item.photoURL)
    }

    private func loadImageData(named filename: String?) -> Data? {
        guard let filename else { return nil }
        return try? imageStore.loadData(named: filename)
    }

    private func makeTotalSpendText() -> String {
        let total = rows.reduce(0) { $0 + $1.item.price }
        let amount = "你已經花了\(PriceText.amount(total))$"
        guard let userName, !userName.isEmpty else { return amount }
        return "\(userName)，\(amount)"
    }
}

// MARK: - ShoppingListViewModelInput

extension ShoppingListViewModel: ShoppingListViewModelInput {

    func viewDidLoad() {
        do {
            rows = try repository.load().map { Row(item: $0) }
        } catch {
            rows = []
            errorMessageSubject.send("購物清單讀取失敗")
        }
        publish()
    }

    func deleteItem(at index: Int) {
        guard rows.indices.contains(index) else { return }
        let removed = rows.remove(at: index)
        if let photoName = removed.item.photoURL {
            removedPhotoNames.append(photoName)
        }
        publish()
    }

    func itemSelected(at index: Int) {
        guard rows.indices.contains(index) else { return }
        let row = rows[index]
        editRequestSubject.send(
            ShoppingListEditRequest(index: index, item: row.item, photoData: photoData(for: row))
        )
    }

    /// 編輯和刪除一樣先留在記憶體，按下 Done 才寫檔。
    func itemEdited(at index: Int, _ edit: ItemEdit) {
        guard rows.indices.contains(index) else { return }
        var item = edit.item
        // 照片檔名由清單管理，編輯頁不能改掉它。
        item.photoURL = rows[index].item.photoURL
        rows[index].item = item
        if let data = edit.newPhotoData {
            rows[index].newPhotoData = data
        }
        publish()
    }

    /// 刪除與編輯都不會立即寫檔，只有按下 Done 才儲存，
    /// 這樣誤刪或改錯時可以直接返回而不套用變更。
    func doneTapped() {
        var savedPhotoNames: [String] = []
        var replacedPhotoNames: [String] = []
        var items: [ShoppingItem] = []

        for row in rows {
            var item = row.item
            if let data = row.newPhotoData {
                do {
                    let name = try imageStore.save(data)
                    savedPhotoNames.append(name)
                    if let oldName = item.photoURL {
                        replacedPhotoNames.append(oldName)
                    }
                    item.photoURL = name
                } catch {
                    savedPhotoNames.forEach { try? imageStore.remove(named: $0) }
                    errorMessageSubject.send("照片儲存失敗，請再試一次")
                    return
                }
            }
            items.append(item)
        }

        do {
            try repository.save(items)
        } catch {
            // 清單沒存成功，剛寫入的新照片沒有人引用，一併移除。
            savedPhotoNames.forEach { try? imageStore.remove(named: $0) }
            errorMessageSubject.send("購物清單儲存失敗，請再試一次")
            return
        }
        rows = items.map { Row(item: $0) }

        // 存檔成功後才清掉圖片，避免存檔失敗卻已刪除圖片。
        (removedPhotoNames + replacedPhotoNames).forEach { try? imageStore.remove(named: $0) }
        removedPhotoNames.removeAll()

        didFinishSubject.send(())
    }
}

// MARK: - ShoppingListViewModelOutput

extension ShoppingListViewModel: ShoppingListViewModelOutput {

    var items: AnyPublisher<[ShoppingListItem], Never> { itemsSubject.eraseToAnyPublisher() }
    var totalSpendText: AnyPublisher<String, Never> { totalSpendTextSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didFinish: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }
    var editRequest: AnyPublisher<ShoppingListEditRequest, Never> { editRequestSubject.eraseToAnyPublisher() }
}
