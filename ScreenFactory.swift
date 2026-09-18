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
    /// 尚未完成引導流程時為 true。
    var needsOnboarding: Bool { get }
    /// 引導流程：輸入稱呼 → 建立第一個專案。兩者齊備才算完成。
    func makeOnboarding(onFinish: @escaping () -> Void) -> UIViewController
    func makeSettings(onFinish: @escaping () -> Void) -> UIViewController
    func makeTripList(onTripChanged: @escaping () -> Void) -> UIViewController
    func makeTripEditor(editing trip: Trip?, onFinish: @escaping () -> Void) -> UIViewController
    func makeCompute() -> UIViewController
    func makeDetail(item: ShoppingItem, onSaved: @escaping () -> Void) -> UIViewController
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
    private let tripRepository: TripRepository
    private let tripContentStore: TripContentStore

    init(
        cardRepository: CardRepository = FileCardRepository(),
        shoppingListRepository: ShoppingListRepository = FileShoppingListRepository(),
        imageStore: ImageStore = FileImageStore(),
        exchangeRateService: ExchangeRateService = RemoteExchangeRateService(),
        userProfileRepository: UserProfileRepository = UserDefaultsUserProfileRepository(),
        tripRepository: TripRepository = FileTripRepository(),
        tripContentStore: TripContentStore = FileTripContentStore()
    ) {
        self.cardRepository = cardRepository
        self.shoppingListRepository = shoppingListRepository
        self.imageStore = imageStore
        self.exchangeRateService = exchangeRateService
        self.userProfileRepository = userProfileRepository
        self.tripRepository = tripRepository
        self.tripContentStore = tripContentStore

        // 舊版的單一清單轉成第一個專案，只會執行一次。
        TripMigration.run(tripRepository: tripRepository)
    }

    /// 目前使用中的專案。沒有選中時退回最新建立的一個。
    private var currentTrip: Trip? {
        let trips = (try? tripRepository.load()) ?? []
        if let id = tripRepository.loadCurrentTripID(), let trip = trips.first(where: { $0.id == id }) {
            return trip
        }
        return trips.sorted { $0.createdAt > $1.createdAt }.first
    }

    private var currentShoppingListRepository: ShoppingListRepository {
        guard let currentTrip else { return shoppingListRepository }
        return tripContentStore.shoppingListRepository(for: currentTrip.id)
    }

    var needsOnboarding: Bool {
        userProfileRepository.load() == nil || currentTrip == nil
    }

    func makeOnboarding(onFinish: @escaping () -> Void) -> UIViewController {
        let navigationController = UINavigationController()
        AppAppearance.apply(to: navigationController.navigationBar)

        let welcome = WelcomeViewController(viewModel: WelcomeViewModel())
        welcome.bindFinish { [weak navigationController] name in
            // 名字先寫入，專案由下一步建立；兩者齊備才算完成引導。
            try? self.userProfileRepository.save(UserProfile(name: name))

            let editor = TripEditorViewController(
                viewModel: TripEditorViewModel(repository: self.tripRepository),
                presentation: .onboarding
            )
            editor.bindFinish(onFinish)
            navigationController?.pushViewController(editor, animated: true)
        }
        navigationController.setViewControllers([welcome], animated: false)
        return navigationController
    }

    func makeSettings(onFinish: @escaping () -> Void) -> UIViewController {
        let controller = SettingsViewController(
            viewModel: SettingsViewModel(repository: userProfileRepository)
        )
        controller.onFinish = onFinish
        return controller
    }

    func makeCompute() -> UIViewController {
        let viewModel = ComputeViewModel(
            service: exchangeRateService,
            tripRepository: tripRepository
        )
        return ComputeViewController(viewModel: viewModel, factory: self)
    }

    func makeDetail(item: ShoppingItem, onSaved: @escaping () -> Void) -> UIViewController {
        let viewModel = DetailViewModel(
            item: item,
            cardRepository: cardRepository,
            shoppingListRepository: currentShoppingListRepository,
            imageStore: imageStore
        )
        let controller = DetailViewController(viewModel: viewModel, factory: self)
        controller.onSaved = onSaved
        return controller
    }

    func makeTripList(onTripChanged: @escaping () -> Void) -> UIViewController {
        let viewModel = TripListViewModel(repository: tripRepository, contentStore: tripContentStore)
        let controller = TripListViewController(viewModel: viewModel, factory: self)
        controller.onTripChanged = onTripChanged
        return controller
    }

    func makeTripEditor(editing trip: Trip?, onFinish: @escaping () -> Void) -> UIViewController {
        let controller = TripEditorViewController(
            viewModel: TripEditorViewModel(editingTrip: trip, repository: tripRepository),
            presentation: trip == nil ? .create : .edit
        )
        controller.bindFinish { [weak controller] in
            onFinish()
            controller?.navigationController?.popViewController(animated: true)
        }
        return controller
    }

    func makeShoppingList() -> UIViewController {
        let viewModel = ShoppingListViewModel(
            repository: currentShoppingListRepository,
            imageStore: imageStore,
            userProfileRepository: userProfileRepository
        )
        return ShoppingListViewController(viewModel: viewModel)
    }

    func makeCardSet(onFinish: @escaping () -> Void) -> UIViewController {
        let controller = CardSetViewController(viewModel: CardSetViewModel(repository: cardRepository))
        controller.onFinish = onFinish
        return controller
    }

    func makeCardList(onFinish: @escaping () -> Void) -> UIViewController {
        let controller = CardListViewController(
            viewModel: CardListViewModel(repository: cardRepository),
            factory: self
        )
        controller.onFinish = onFinish
        return controller
    }
}
