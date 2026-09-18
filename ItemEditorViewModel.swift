//
//  ItemEditorViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

/// 編輯完成的結果。新照片只帶資料，等清單按下「完成」才寫檔，
/// 這樣從清單直接返回放棄變更時不會留下沒人用的圖片。
struct ItemEdit: Equatable {
    let item: ShoppingItem
    let newPhotoData: Data?
}

protocol ItemEditorViewModelType {
    var input: ItemEditorViewModelInput { get }
    var output: ItemEditorViewModelOutput { get }
}

protocol ItemEditorViewModelInput {
    func viewDidLoad()
    func productNameChanged(_ text: String)
    func priceTextChanged(_ text: String)
    func taxModeChanged(to mode: TaxMode)
    func payTypeSelected(at index: Int)
    func photoSelected(_ data: Data?)
    func saveTapped()
}

protocol ItemEditorViewModelOutput {
    var productName: AnyPublisher<String, Never> { get }
    var priceText: AnyPublisher<String, Never> { get }
    /// 舊資料的稅別不是「未稅」或「含稅」時為 nil，畫面不選取任何一段。
    var selectedTaxMode: AnyPublisher<TaxMode?, Never> { get }
    var payTypeTitle: AnyPublisher<String, Never> { get }
    var payTypeOptions: AnyPublisher<[String], Never> { get }
    var photoData: AnyPublisher<Data?, Never> { get }
    var isSaveEnabled: AnyPublisher<Bool, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didSave: AnyPublisher<ItemEdit, Never> { get }
}

// MARK: - ViewModel

/// 修改購物清單中已存在的一筆消費。
///
/// 這是更正紀錄，不是新的消費：改付款方式不會重新扣信用卡的回饋額度。
final class ItemEditorViewModel: ItemEditorViewModelType {

    private enum Constants {
        static let cash = "現金"
    }

    private let cardRepository: CardRepository

    private var item: ShoppingItem
    private var enteredPriceText: String
    private var newPhotoData: Data?
    private var options: [String] = []

    private let productNameSubject: CurrentValueSubject<String, Never>
    private let priceTextSubject: CurrentValueSubject<String, Never>
    private let selectedTaxModeSubject: CurrentValueSubject<TaxMode?, Never>
    private let payTypeTitleSubject: CurrentValueSubject<String, Never>
    private let payTypeOptionsSubject = CurrentValueSubject<[String], Never>([])
    private let photoDataSubject: CurrentValueSubject<Data?, Never>
    private let isSaveEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didSaveSubject = PassthroughSubject<ItemEdit, Never>()

    init(item: ShoppingItem, photoData: Data?, cardRepository: CardRepository) {
        self.item = item
        self.cardRepository = cardRepository
        self.enteredPriceText = PriceText.amount(item.price)
        self.productNameSubject = CurrentValueSubject(item.productName)
        self.priceTextSubject = CurrentValueSubject(PriceText.amount(item.price))
        self.selectedTaxModeSubject = CurrentValueSubject(TaxMode.allCases.first { $0.title == item.taxState })
        self.payTypeTitleSubject = CurrentValueSubject(item.payType)
        self.photoDataSubject = CurrentValueSubject(photoData)
    }

    var input: ItemEditorViewModelInput { self }
    var output: ItemEditorViewModelOutput { self }

    // MARK: - Private

    /// 現金 + 目前的卡片。原本的付款方式若已不在清單中（卡片被刪除、舊資料的「信用卡」），
    /// 仍保留在最後，讓使用者不改付款方式時原值不會被換掉。
    private func makeOptions(cards: [Card]) -> [String] {
        var options = [Constants.cash] + cards.map(\.name)
        if !item.payType.isEmpty, !options.contains(item.payType) {
            options.append(item.payType)
        }
        return options
    }

    private var parsedPrice: Double? {
        guard let price = Double(enteredPriceText), price.isFinite, price >= 0 else { return nil }
        return price
    }

    private func updateSaveEnabled() {
        let hasName = !item.productName.trimmingCharacters(in: .whitespaces).isEmpty
        isSaveEnabledSubject.send(hasName && parsedPrice != nil)
    }
}

// MARK: - ItemEditorViewModelInput

extension ItemEditorViewModel: ItemEditorViewModelInput {

    func viewDidLoad() {
        let cards: [Card]
        do {
            cards = try cardRepository.load()
        } catch {
            cards = []
            errorMessageSubject.send("信用卡資料讀取失敗")
        }
        options = makeOptions(cards: cards)
        payTypeOptionsSubject.send(options)
        updateSaveEnabled()
    }

    func productNameChanged(_ text: String) {
        item.productName = text
        updateSaveEnabled()
    }

    func priceTextChanged(_ text: String) {
        enteredPriceText = text.trimmingCharacters(in: .whitespaces)
        updateSaveEnabled()
    }

    func taxModeChanged(to mode: TaxMode) {
        item.taxState = mode.title
        selectedTaxModeSubject.send(mode)
    }

    func payTypeSelected(at index: Int) {
        guard options.indices.contains(index) else { return }
        item.payType = options[index]
        payTypeTitleSubject.send(item.payType)
    }

    func photoSelected(_ data: Data?) {
        guard let data else { return }
        newPhotoData = data
        photoDataSubject.send(data)
    }

    func saveTapped() {
        guard let price = parsedPrice else { return }
        let name = item.productName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        var edited = item
        edited.productName = name
        edited.price = price
        didSaveSubject.send(ItemEdit(item: edited, newPhotoData: newPhotoData))
    }
}

// MARK: - ItemEditorViewModelOutput

extension ItemEditorViewModel: ItemEditorViewModelOutput {

    var productName: AnyPublisher<String, Never> { productNameSubject.eraseToAnyPublisher() }
    var priceText: AnyPublisher<String, Never> { priceTextSubject.eraseToAnyPublisher() }
    var selectedTaxMode: AnyPublisher<TaxMode?, Never> { selectedTaxModeSubject.eraseToAnyPublisher() }
    var payTypeTitle: AnyPublisher<String, Never> { payTypeTitleSubject.eraseToAnyPublisher() }
    var payTypeOptions: AnyPublisher<[String], Never> { payTypeOptionsSubject.eraseToAnyPublisher() }
    var photoData: AnyPublisher<Data?, Never> { photoDataSubject.eraseToAnyPublisher() }
    var isSaveEnabled: AnyPublisher<Bool, Never> { isSaveEnabledSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didSave: AnyPublisher<ItemEdit, Never> { didSaveSubject.eraseToAnyPublisher() }
}
