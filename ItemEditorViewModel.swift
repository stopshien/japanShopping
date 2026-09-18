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
    func productNameChanged(_ text: String)
    func photoSelected(_ data: Data?)
    func saveTapped()
}

protocol ItemEditorViewModelOutput {
    var productName: AnyPublisher<String, Never> { get }
    /// 唯讀，例如「205$（未稅）」。
    var priceDescription: AnyPublisher<String, Never> { get }
    /// 唯讀。
    var payTypeDescription: AnyPublisher<String, Never> { get }
    var photoData: AnyPublisher<Data?, Never> { get }
    var isSaveEnabled: AnyPublisher<Bool, Never> { get }
    var didSave: AnyPublisher<ItemEdit, Never> { get }
}

// MARK: - ViewModel

/// 修改消費紀錄中已存在的一筆。
///
/// 只能改商品名稱與照片。價格、未稅／含稅與付款方式在加入紀錄時已用來計算信用卡回饋，
/// 事後修改會讓回饋餘額與紀錄對不上，所以只顯示、不開放修改。
final class ItemEditorViewModel: ItemEditorViewModelType {

    private var item: ShoppingItem
    private var newPhotoData: Data?

    private let productNameSubject: CurrentValueSubject<String, Never>
    private let priceDescriptionSubject: CurrentValueSubject<String, Never>
    private let payTypeDescriptionSubject: CurrentValueSubject<String, Never>
    private let photoDataSubject: CurrentValueSubject<Data?, Never>
    private let isSaveEnabledSubject: CurrentValueSubject<Bool, Never>
    private let didSaveSubject = PassthroughSubject<ItemEdit, Never>()

    init(item: ShoppingItem, photoData: Data?) {
        self.item = item
        self.productNameSubject = CurrentValueSubject(item.productName)
        self.priceDescriptionSubject = CurrentValueSubject("\(PriceText.amount(item.price))$（\(item.taxState)）")
        self.payTypeDescriptionSubject = CurrentValueSubject(item.payType)
        self.photoDataSubject = CurrentValueSubject(photoData)
        self.isSaveEnabledSubject = CurrentValueSubject(Self.isValidName(item.productName))
    }

    var input: ItemEditorViewModelInput { self }
    var output: ItemEditorViewModelOutput { self }

    // MARK: - Private

    private static func isValidName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - ItemEditorViewModelInput

extension ItemEditorViewModel: ItemEditorViewModelInput {

    func productNameChanged(_ text: String) {
        item.productName = text
        isSaveEnabledSubject.send(Self.isValidName(text))
    }

    func photoSelected(_ data: Data?) {
        guard let data else { return }
        newPhotoData = data
        photoDataSubject.send(data)
    }

    func saveTapped() {
        guard Self.isValidName(item.productName) else { return }

        var edited = item
        edited.productName = item.productName.trimmingCharacters(in: .whitespaces)
        didSaveSubject.send(ItemEdit(item: edited, newPhotoData: newPhotoData))
    }
}

// MARK: - ItemEditorViewModelOutput

extension ItemEditorViewModel: ItemEditorViewModelOutput {

    var productName: AnyPublisher<String, Never> { productNameSubject.eraseToAnyPublisher() }
    var priceDescription: AnyPublisher<String, Never> { priceDescriptionSubject.eraseToAnyPublisher() }
    var payTypeDescription: AnyPublisher<String, Never> { payTypeDescriptionSubject.eraseToAnyPublisher() }
    var photoData: AnyPublisher<Data?, Never> { photoDataSubject.eraseToAnyPublisher() }
    var isSaveEnabled: AnyPublisher<Bool, Never> { isSaveEnabledSubject.eraseToAnyPublisher() }
    var didSave: AnyPublisher<ItemEdit, Never> { didSaveSubject.eraseToAnyPublisher() }
}
