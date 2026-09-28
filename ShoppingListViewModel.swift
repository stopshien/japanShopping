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

/// 同一天的消費。沒有日期的舊紀錄集中在一區。
struct ShoppingListSection: Equatable {
    /// 例如「9/28（日）」，不是今年時加上年份。
    let title: String
    /// 當天小計，例如「NT$ 1,254」。
    let subtotal: String
    let items: [ShoppingListItem]
}

/// 消費紀錄的日期排序。區塊與區塊內的每一筆都依此排列。
/// `title` 是 VoiceOver 唸出的目前狀態。
enum ShoppingListSortOrder {
    case oldestFirst
    case newestFirst

    var title: String {
        switch self {
        case .oldestFirst: return "舊到新"
        case .newestFirst: return "新到舊"
        }
    }
}

/// 要開啟編輯頁的那一筆。
struct ShoppingListEditRequest: Equatable {
    /// 在整份清單中的位置，編輯完成時原樣傳回 `itemEdited(at:_:)`。
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
    func deleteItem(at indexPath: IndexPath)
    func itemSelected(at indexPath: IndexPath)
    func itemEdited(at index: Int, _ edit: ItemEdit)
    /// 在舊到新與新到舊之間切換。
    func sortOrderToggled()
    func doneTapped()
}

protocol ShoppingListViewModelOutput {
    var sections: AnyPublisher<[ShoppingListSection], Never> { get }
    /// 底部的總金額大字，例如「NT$ 51」。
    var totalAmount: AnyPublisher<String, Never> { get }
    /// 總金額下方的說明，例如「共 3 筆・Angus」。
    var totalSummary: AnyPublisher<String, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var sortOrder: AnyPublisher<ShoppingListSortOrder, Never> { get }
    var didFinish: AnyPublisher<Void, Never> { get }
    var editRequest: AnyPublisher<ShoppingListEditRequest, Never> { get }
}

// MARK: - ViewModel

final class ShoppingListViewModel: ShoppingListViewModelType {

    private let repository: ShoppingListRepository
    private let imageStore: ImageStore
    /// 歡迎頁設定的稱呼。沒有設定時總金額就用不帶稱呼的句子。
    private let userName: String?
    private let calendar: Calendar
    private let now: () -> Date

    private var rows: [ShoppingItem] = []
    /// 每一區包含的列在 `rows` 中的位置，依畫面上的順序排列，
    /// 把畫面上的 IndexPath 轉回清單位置。
    private var sectionRowIndices: [[Int]] = []

    private let sortOrderSubject = CurrentValueSubject<ShoppingListSortOrder, Never>(.oldestFirst)
    private let sectionsSubject = CurrentValueSubject<[ShoppingListSection], Never>([])
    private let totalAmountSubject = CurrentValueSubject<String, Never>("")
    private let totalSummarySubject = CurrentValueSubject<String, Never>("")
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didFinishSubject = PassthroughSubject<Void, Never>()
    private let editRequestSubject = PassthroughSubject<ShoppingListEditRequest, Never>()

    init(
        repository: ShoppingListRepository,
        imageStore: ImageStore,
        userProfileRepository: UserProfileRepository,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.imageStore = imageStore
        self.userName = userProfileRepository.load()?.name
        self.calendar = calendar
        self.now = now
    }

    var input: ShoppingListViewModelInput { self }
    var output: ShoppingListViewModelOutput { self }

    // MARK: - Private

    private func publish() {
        let groups = groupRowIndicesByDay()
        switch sortOrderSubject.value {
        case .oldestFirst:
            sectionRowIndices = groups
        case .newestFirst:
            // 存檔依加入順序排列，反轉即是新到舊；沒有日期的舊紀錄因此落到最後。
            sectionRowIndices = groups.reversed().map { $0.reversed() }
        }
        sectionsSubject.send(sectionRowIndices.map(makeSection))
        totalAmountSubject.send(PriceText.twd(rows.reduce(0) { $0 + $1.price }))
        totalSummarySubject.send(makeTotalSummary())
    }

    /// 清單依加入順序存放，同一天的紀錄一定相鄰，所以只要把相鄰且同一天的列歸成一區。
    private func groupRowIndicesByDay() -> [[Int]] {
        var groups: [[Int]] = []
        var currentDay: Date??
        for (index, item) in rows.enumerated() {
            let day = item.purchasedAt.map { calendar.startOfDay(for: $0) }
            if let currentDay, currentDay == day {
                groups[groups.count - 1].append(index)
            } else {
                groups.append([index])
                currentDay = day
            }
        }
        return groups
    }

    private func makeSection(rowIndices: [Int]) -> ShoppingListSection {
        let items = rowIndices.map { rows[$0] }
        return ShoppingListSection(
            title: sectionTitle(for: items.first?.purchasedAt),
            subtotal: PriceText.twd(items.reduce(0) { $0 + $1.price }),
            items: items.map(makeDisplayItem)
        )
    }

    /// 「9/28（日）」；不是今年的加上年份，避免跨年的紀錄看起來像同一天。
    private func sectionTitle(for date: Date?) -> String {
        guard let date else { return "較早的紀錄" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "zh_TW")
        let isThisYear = calendar.isDate(date, equalTo: now(), toGranularity: .year)
        formatter.dateFormat = isThisYear ? "M/d（EEEEE）" : "yyyy/M/d（EEEEE）"
        return formatter.string(from: date)
    }

    private func rowIndex(for indexPath: IndexPath) -> Int? {
        guard sectionRowIndices.indices.contains(indexPath.section),
              sectionRowIndices[indexPath.section].indices.contains(indexPath.row) else { return nil }
        return sectionRowIndices[indexPath.section][indexPath.row]
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
    func deleteItem(at indexPath: IndexPath) {
        guard let index = rowIndex(for: indexPath) else { return }
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

    func itemSelected(at indexPath: IndexPath) {
        guard let index = rowIndex(for: indexPath) else { return }
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
        // 照片檔名與日期由清單管理，編輯頁不能改掉它們。
        item.photoURL = oldPhotoName
        item.purchasedAt = rows[index].purchasedAt

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

    /// 只改變顯示順序，不動存檔。
    func sortOrderToggled() {
        sortOrderSubject.send(sortOrderSubject.value == .oldestFirst ? .newestFirst : .oldestFirst)
        publish()
    }

    /// 變更都已即時寫檔，「完成」只負責回到首頁。
    func doneTapped() {
        didFinishSubject.send(())
    }
}

// MARK: - ShoppingListViewModelOutput

extension ShoppingListViewModel: ShoppingListViewModelOutput {

    var sections: AnyPublisher<[ShoppingListSection], Never> { sectionsSubject.eraseToAnyPublisher() }
    var totalAmount: AnyPublisher<String, Never> { totalAmountSubject.eraseToAnyPublisher() }
    var totalSummary: AnyPublisher<String, Never> { totalSummarySubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var sortOrder: AnyPublisher<ShoppingListSortOrder, Never> { sortOrderSubject.eraseToAnyPublisher() }
    var didFinish: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }
    var editRequest: AnyPublisher<ShoppingListEditRequest, Never> { editRequestSubject.eraseToAnyPublisher() }
}
