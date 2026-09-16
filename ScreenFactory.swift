//
//  ScreenFactory.swift
//  japanShopping
//

import UIKit

/// 建立畫面的唯一位置。
///
/// 畫面之間需要互相導航，但 view controller 不應該知道 repository 的具體型別，
/// 所以由這裡集中組裝，再以初始化注入給需要導航的畫面。
protocol ScreenFactory {
    func makeCompute() -> UIViewController
    func makeDetail(item: ShoppingItem) -> UIViewController
    func makeShoppingList() -> UIViewController
    func makeCardSet(onFinish: @escaping () -> Void) -> UIViewController
    func makeCardList(onFinish: @escaping () -> Void) -> UIViewController
}

final class AppScreenFactory: ScreenFactory {

    private let cardRepository: CardRepository
    private let shoppingListRepository: ShoppingListRepository
    private let imageStore: ImageStore
    private let exchangeRateService: ExchangeRateService

    init(
        cardRepository: CardRepository = FileCardRepository(),
        shoppingListRepository: ShoppingListRepository = FileShoppingListRepository(),
        imageStore: ImageStore = FileImageStore(),
        exchangeRateService: ExchangeRateService = RemoteExchangeRateService()
    ) {
        self.cardRepository = cardRepository
        self.shoppingListRepository = shoppingListRepository
        self.imageStore = imageStore
        self.exchangeRateService = exchangeRateService
    }

    func makeCompute() -> UIViewController {
        let viewModel = ComputeViewModel(service: exchangeRateService)
        return ComputeViewController(viewModel: viewModel, factory: self)
    }

    func makeDetail(item: ShoppingItem) -> UIViewController {
        let viewModel = DetailViewModel(
            item: item,
            cardRepository: cardRepository,
            shoppingListRepository: shoppingListRepository,
            imageStore: imageStore
        )
        return DetailViewController(viewModel: viewModel, factory: self)
    }

    func makeShoppingList() -> UIViewController {
        let viewModel = ShoppingListViewModel(
            repository: shoppingListRepository,
            imageStore: imageStore
        )
        return ShoppingListViewController(viewModel: viewModel)
    }

    func makeCardSet(onFinish: @escaping () -> Void) -> UIViewController {
        let controller = CardSetViewController(viewModel: CardSetViewModel(repository: cardRepository))
        controller.onFinish = onFinish
        return controller
    }

    func makeCardList(onFinish: @escaping () -> Void) -> UIViewController {
        let controller = CardListViewController(viewModel: CardListViewModel(repository: cardRepository))
        controller.onFinish = onFinish
        return controller
    }
}
