//
//  LegacyScreenFactory.swift
//  japanShopping
//

import UIKit

/// 尚未遷移的畫面用來建立已遷移畫面的橋接點。
/// 等 ComputeViewController 也遷移完成後，改由它的 ViewModel 發出 route 事件，這個檔案就可以刪除。
extension UIViewController {

    func makeDetailViewController(item: ShoppingItem) -> DetailViewController {
        let viewModel = DetailViewModel(
            item: item,
            cardRepository: FileCardRepository(),
            shoppingListRepository: FileShoppingListRepository(),
            imageStore: FileImageStore()
        )
        return DetailViewController(viewModel: viewModel)
    }

    func makeShoppingListViewController() -> ShoppingListViewController {
        let viewModel = ShoppingListViewModel(
            repository: FileShoppingListRepository(),
            imageStore: FileImageStore()
        )
        return ShoppingListViewController(viewModel: viewModel)
    }

    func makeCardSetViewController() -> CardSetViewController {
        CardSetViewController(viewModel: CardSetViewModel(repository: FileCardRepository()))
    }

    func makeCardListViewController() -> CardListViewController {
        CardListViewController(viewModel: CardListViewModel(repository: FileCardRepository()))
    }
}
