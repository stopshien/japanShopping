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
    /// 尚未設定稱呼時為 true，代表要先顯示歡迎頁。
    var needsWelcome: Bool { get }
    func makeWelcome(onFinish: @escaping () -> Void) -> UIViewController
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
    private let userProfileRepository: UserProfileRepository

    init(
        cardRepository: CardRepository = FileCardRepository(),
        shoppingListRepository: ShoppingListRepository = FileShoppingListRepository(),
        imageStore: ImageStore = FileImageStore(),
        exchangeRateService: ExchangeRateService = RemoteExchangeRateService(),
        userProfileRepository: UserProfileRepository = UserDefaultsUserProfileRepository()
    ) {
        self.cardRepository = cardRepository
        self.shoppingListRepository = shoppingListRepository
        self.imageStore = imageStore
        self.exchangeRateService = exchangeRateService
        self.userProfileRepository = userProfileRepository
    }

    var needsWelcome: Bool {
        userProfileRepository.load() == nil
    }

    func makeWelcome(onFinish: @escaping () -> Void) -> UIViewController {
        let viewModel = WelcomeViewModel(repository: userProfileRepository)
        let controller = WelcomeViewController(viewModel: viewModel)
        controller.bindFinish(onFinish)
        return controller
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
