//
//  ShoppingListFactory.swift
//  japanShopping
//

import UIKit

/// 尚未遷移的畫面用來建立購物清單畫面的橋接點。
/// 等 Compute 與 Detail 也遷移完成後，改由各自的 ViewModel 發出 route 事件，這個檔案就可以刪除。
extension UIViewController {

    func makeShoppingListViewController() -> ShoppingListViewController {
        let viewModel = ShoppingListViewModel(
            repository: FileShoppingListRepository(),
            imageStore: FileImageStore()
        )
        return ShoppingListViewController(viewModel: viewModel)
    }
}
