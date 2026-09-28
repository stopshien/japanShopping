//
//  ShoppingListViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

struct ShoppingListItem: Equatable {
    let productName: String
    /// 大字金額，例如「NT$ 100」。
    let amount: String
    /// 金額旁的小標籤，「未稅」或「含稅」。
    let taxState: String
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
    /// 刪除會立即寫檔，呼叫前畫面須先向使用者確認。
    func deleteItem(at index: Int)
    func itemSelected(at index: Int)
    func itemEdited(at index: Int, _ edit: ItemEdit)
    func doneTapped()
}

protocol ShoppingListViewModelOutput {
    var items: AnyPublisher<[ShoppingListItem], Never> { get }
    /// 底部的總金額大字，例如「NT$ 51」。
    var totalAmount: AnyPublisher<String, Never> { get }
    /// 總金額下方的說明，例如「共 3 筆・Angus」。
    var totalSummary: AnyPublisher<String, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didFinish: AnyPublisher<Void, Never> { get }
    var editRequest: AnyPublisher<ShoppingListEditRequest, Never> { get }
}

// MARK: - ViewModel

final class ShoppingListViewModel: ShoppingListViewModelType {

    private let repository: ShoppingListRepository
    private let imageStore: ImageStore
    /// 歡迎頁設定的稱呼。沒有設定時總金額就用不帶稱呼的句子。
    private let userName: String?

    private var rows: [ShoppingItem] = []

    private let itemsSubject = CurrentValueSubject<[ShoppingListItem], Never>([])
    private let totalAmountSubject = CurrentValueSubject<String, Never>("")
    private let totalSummarySubject = CurrentValueSubject<String, Never>("")
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
        totalAmountSubject.send(PriceText.twd(rows.reduce(0) { $0 + $1.price }))
        totalSummarySubject.send(makeTotalSummary())
    }

    private func makeDisplayItem(from item: ShoppingItem) -> ShoppingListItem {
        ShoppingListItem(
            productName: item.productName,
            amount: PriceText.twd(item.price),
            taxState: item.taxState,
            payType: item.payType,
            imageData: loadImageData(named: item.photoURL)
        )
    }

    private func loadImageData(named filename: String?) -> Data? {
        guard let filename else { return nil }
        return try? imageStore.loadData(named: filename)
    }

    /// 例如「共 3 筆・Angus」。沒有稱呼時只顯示筆數。
    private func makeTotalSummary() -> String {
        let count = "共 \(rows.count) 筆"
        guard let userName, !userName.isEmpty else { return count }
        return "\(count)・\(userName)"
    }

    /// 寫入整份清單。失敗時回報錯誤並回傳 false，由呼叫端還原畫面上的資料。
    private func persist(_ items: [ShoppingItem]) -> Bool {
        do {
            try repository.save(items)
            return true
        } catch {
            errorMessageSubject.send("消費紀錄儲存失敗，請再試一次")
            return false
        }
    }
}

// MARK: - ShoppingListViewModelInput

extension ShoppingListViewModel: ShoppingListViewModelInput {

    func viewDidLoad() {
        do {
            rows = try repository.load()
        } catch {
            rows = []
            errorMessageSubject.send("消費紀錄讀取失敗")
        }
        publish()
    }

    /// 刪除立即寫檔；誤刪的保護由畫面上的確認提示負責。
    func deleteItem(at index: Int) {
        guard rows.indices.contains(index) else { return }
        var updated = rows
        let removed = updated.remove(at: index)
        guard persist(updated) else { return }
        rows = updated
        // 存檔成功後才刪圖片，避免存檔失敗卻已刪除圖片。
        if let photoName = removed.photoURL {
            try? imageStore.remove(named: photoName)
        }
        publish()
    }

    func itemSelected(at index: Int) {
        guard rows.indices.contains(index) else { return }
        let item = rows[index]
        editRequestSubject.send(
            ShoppingListEditRequest(index: index, item: item, photoData: loadImageData(named: item.photoURL))
        )
    }

    /// 編輯頁按下「儲存」就立即寫檔，新照片取代舊照片。
    func itemEdited(at index: Int, _ edit: ItemEdit) {
        guard rows.indices.contains(index) else { return }
        var item = edit.item
        let oldPhotoName = rows[index].photoURL
        // 照片檔名由清單管理，編輯頁不能改掉它。
        item.photoURL = oldPhotoName

        var newPhotoName: String?
        if let data = edit.newPhotoData {
            do {
                newPhotoName = try imageStore.save(data)
                item.photoURL = newPhotoName
            } catch {
                errorMessageSubject.send("照片儲存失敗，請再試一次")
                return
            }
        }

        var updated = rows
        updated[index] = item
        guard persist(updated) else {
            // 清單沒存成功，剛寫入的新照片沒有人引用，一併移除；舊照片保留。
            if let newPhotoName {
                try? imageStore.remove(named: newPhotoName)
            }
            return
        }
        rows = updated
        if newPhotoName != nil, let oldPhotoName {
            try? imageStore.remove(named: oldPhotoName)
        }
        publish()
    }

    /// 變更都已即時寫檔，「完成」只負責回到首頁。
    func doneTapped() {
        didFinishSubject.send(())
    }
}

// MARK: - ShoppingListViewModelOutput

extension ShoppingListViewModel: ShoppingListViewModelOutput {

    var items: AnyPublisher<[ShoppingListItem], Never> { itemsSubject.eraseToAnyPublisher() }
    var totalAmount: AnyPublisher<String, Never> { totalAmountSubject.eraseToAnyPublisher() }
    var totalSummary: AnyPublisher<String, Never> { totalSummarySubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didFinish: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }
    var editRequest: AnyPublisher<ShoppingListEditRequest, Never> { editRequestSubject.eraseToAnyPublisher() }
}
