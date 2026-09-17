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

protocol ShoppingListViewModelType {
    var input: ShoppingListViewModelInput { get }
    var output: ShoppingListViewModelOutput { get }
}

protocol ShoppingListViewModelInput {
    func viewDidLoad()
    func deleteItem(at index: Int)
    func doneTapped()
}

protocol ShoppingListViewModelOutput {
    var items: AnyPublisher<[ShoppingListItem], Never> { get }
    var totalSpendText: AnyPublisher<String, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didFinish: AnyPublisher<Void, Never> { get }
}

// MARK: - ViewModel

final class ShoppingListViewModel: ShoppingListViewModelType {

    private let repository: ShoppingListRepository
    private let imageStore: ImageStore
    /// 歡迎頁設定的稱呼。沒有設定時總金額就用不帶稱呼的句子。
    private let userName: String?

    private var shoppingItems: [ShoppingItem] = []
    /// 已從清單移除、待按下 Done 時一併刪除的圖片檔名。
    private var removedPhotoNames: [String] = []

    private let itemsSubject = CurrentValueSubject<[ShoppingListItem], Never>([])
    private let totalSpendTextSubject = CurrentValueSubject<String, Never>("")
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didFinishSubject = PassthroughSubject<Void, Never>()

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
        itemsSubject.send(shoppingItems.map(makeDisplayItem))
        totalSpendTextSubject.send(makeTotalSpendText())
    }

    private func makeDisplayItem(from item: ShoppingItem) -> ShoppingListItem {
        ShoppingListItem(
            productName: item.productName,
            priceDescription: "\(PriceText.amount(item.price))$(\(item.taxState))",
            payType: item.payType,
            imageData: loadImageData(named: item.photoURL)
        )
    }

    private func loadImageData(named filename: String?) -> Data? {
        guard let filename else { return nil }
        return try? imageStore.loadData(named: filename)
    }

    private func makeTotalSpendText() -> String {
        let total = shoppingItems.reduce(0) { $0 + $1.price }
        let amount = "你已經花了\(PriceText.amount(total))$"
        guard let userName, !userName.isEmpty else { return amount }
        return "\(userName)，\(amount)"
    }
}

// MARK: - ShoppingListViewModelInput

extension ShoppingListViewModel: ShoppingListViewModelInput {

    func viewDidLoad() {
        do {
            shoppingItems = try repository.load()
        } catch {
            shoppingItems = []
            errorMessageSubject.send("購物清單讀取失敗")
        }
        publish()
    }

    func deleteItem(at index: Int) {
        guard shoppingItems.indices.contains(index) else { return }
        let removed = shoppingItems.remove(at: index)
        if let photoName = removed.photoURL {
            removedPhotoNames.append(photoName)
        }
        publish()
    }

    /// 刪除不會立即寫檔，只有按下 Done 才儲存，
    /// 這樣誤刪時可以直接返回而不套用變更。
    func doneTapped() {
        do {
            try repository.save(shoppingItems)
        } catch {
            errorMessageSubject.send("購物清單儲存失敗，請再試一次")
            return
        }

        // 存檔成功後才清掉圖片，避免存檔失敗卻已刪除圖片。
        removedPhotoNames.forEach { try? imageStore.remove(named: $0) }
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
}
