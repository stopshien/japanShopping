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
    /// 引導流程：輸入稱呼 →（可選）新增信用卡 → 建立第一個專案。稱呼與專案齊備才算完成。
    func makeOnboarding(onFinish: @escaping () -> Void) -> UIViewController
    /// 設定選項列表。
    func makeSettings() -> UIViewController
    /// 個人資料（稱呼）。
    func makeProfile() -> UIViewController
    func makeTripList(onTripChanged: @escaping () -> Void) -> UIViewController
    func makeTripEditor(editing trip: Trip?, onFinish: @escaping () -> Void) -> UIViewController
    func makeCompute() -> UIViewController
    func makeDetail(item: ShoppingItem, onSaved: @escaping () -> Void) -> UIViewController
    /// `allowsBack` 為 false 時隱藏返回鍵並停用滑動返回，只能按「完成」回到首頁。
    func makeShoppingList(allowsBack: Bool) -> UIViewController
    func makeItemEditor(item: ShoppingItem, photoData: Data?, onSave: @escaping (ItemEdit) -> Void) -> UIViewController
    /// `card` 為 nil 時是新增，否則是編輯那張卡。
    func makeCardSet(editing card: Card?, onFinish: @escaping () -> Void) -> UIViewController
    func makeCardList() -> UIViewController
}

final class AppScreenFactory: ScreenFactory {

    private let cardRepository: CardRepository
    private let shoppingListRepository: ShoppingListRepository
    private let imageStore: ImageStore
    private let exchangeRateService: ExchangeRateService
    private let userProfileRepository: UserProfileRepository
    private let tripRepository: TripRepository
    private let tripContentStore: TripContentStore
    private let ledgerRepository: FeedbackLedgerRepository

    init(
        cardRepository: CardRepository = FileCardRepository(),
        shoppingListRepository: ShoppingListRepository = FileShoppingListRepository(),
        imageStore: ImageStore = FileImageStore(),
        exchangeRateService: ExchangeRateService = RemoteExchangeRateService(),
        userProfileRepository: UserProfileRepository = UserDefaultsUserProfileRepository(),
        tripRepository: TripRepository = FileTripRepository(),
        tripContentStore: TripContentStore = FileTripContentStore(),
        ledgerRepository: FeedbackLedgerRepository = FileFeedbackLedgerRepository()
    ) {
        self.cardRepository = cardRepository
        self.shoppingListRepository = shoppingListRepository
        self.imageStore = imageStore
        self.exchangeRateService = exchangeRateService
        self.userProfileRepository = userProfileRepository
        self.tripRepository = tripRepository
        self.tripContentStore = tripContentStore
        self.ledgerRepository = ledgerRepository

        // 舊版的單一清單轉成第一個專案，只會執行一次。
        TripMigration.run(tripRepository: tripRepository)
        // 替沒有識別碼的卡片與消費補上 id，之後的回饋明細靠它對應。
        IdentityMigration.run(
            cardRepository: cardRepository,
            tripRepository: tripRepository,
            tripContentStore: tripContentStore
        )
        // 已用掉的額度轉成回饋明細；要在補上卡片 id 之後。
        FeedbackLedgerMigration.run(cardRepository: cardRepository, ledgerRepository: ledgerRepository)
        // 舊卡轉成只有一個方案的卡，明細歸到那個方案；要在前兩個遷移之後。
        CardPlanMigration.run(cardRepository: cardRepository, ledgerRepository: ledgerRepository)
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
        welcome.bindFinish { [weak navigationController, weak welcome] name, addsCardFirst in
            // 名字先寫入，專案由最後一步建立；兩者齊備才算完成引導。
            try? self.userProfileRepository.save(UserProfile(name: name))

            let editor = TripEditorViewController(
                viewModel: TripEditorViewModel(repository: self.tripRepository),
                presentation: .onboarding
            )
            editor.bindFinish(onFinish)

            guard addsCardFirst, let welcome else {
                navigationController?.pushViewController(editor, animated: true)
                return
            }

            // 新增或略過信用卡後以建立專案取代信用卡頁，返回時直接回到輸入稱呼，
            // 不會回到已新增過的信用卡表單而重複新增。
            let showEditor: () -> Void = { [weak navigationController] in
                navigationController?.setViewControllers([welcome, editor], animated: true)
            }
            let cardSet = CardSetViewController(viewModel: CardSetViewModel(repository: self.cardRepository))
            cardSet.onFinish = showEditor
            cardSet.onSkip = showEditor
            navigationController?.pushViewController(cardSet, animated: true)
        }
        navigationController.setViewControllers([welcome], animated: false)
        return navigationController
    }

    func makeSettings() -> UIViewController {
        SettingsViewController(viewModel: SettingsViewModel(), factory: self)
    }

    func makeProfile() -> UIViewController {
        ProfileViewController(viewModel: ProfileViewModel(repository: userProfileRepository))
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
            imageStore: imageStore,
            ledgerRepository: ledgerRepository
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

    func makeShoppingList(allowsBack: Bool) -> UIViewController {
        let viewModel = ShoppingListViewModel(
            repository: currentShoppingListRepository,
            imageStore: imageStore,
            userProfileRepository: userProfileRepository,
            ledgerRepository: ledgerRepository
        )
        return ShoppingListViewController(viewModel: viewModel, factory: self, allowsBack: allowsBack)
    }

    func makeItemEditor(item: ShoppingItem, photoData: Data?, onSave: @escaping (ItemEdit) -> Void) -> UIViewController {
        let viewModel = ItemEditorViewModel(item: item, photoData: photoData)
        let controller = ItemEditorViewController(viewModel: viewModel)
        controller.onSave = onSave
        return controller
    }

    func makeCardSet(editing card: Card?, onFinish: @escaping () -> Void) -> UIViewController {
        let controller = CardSetViewController(
            viewModel: CardSetViewModel(editingCard: card, repository: cardRepository)
        )
        controller.onFinish = { [weak controller] in
            onFinish()
            controller?.navigationController?.popViewController(animated: true)
        }
        return controller
    }

    func makeCardList() -> UIViewController {
        CardListViewController(
            viewModel: CardListViewModel(repository: cardRepository, ledgerRepository: ledgerRepository),
            factory: self
        )
    }
}
