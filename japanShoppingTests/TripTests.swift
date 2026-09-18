//
//  TripTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

// MARK: - 建立與編輯專案

final class TripEditorViewModelTests: XCTestCase {

    private var repository: TripRepositoryStub!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        repository = TripRepositoryStub()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        repository = nil
        super.tearDown()
    }

    private func makeViewModel(editing trip: Trip? = nil) -> TripEditorViewModel {
        TripEditorViewModel(editingTrip: trip, repository: repository)
    }

    // MARK: 名稱預設值

    func testNameIsPrefilledWithADefault() {
        let viewModel = makeViewModel()
        var name: String?
        viewModel.output.name.sink { name = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(name, Trip.defaultName(for: .japaneseYen))
    }

    /// 使用者沒改過名稱時，換幣別預設名稱要跟著變。
    func testDefaultNameFollowsTheCurrencyUntilTheUserTypes() {
        let viewModel = makeViewModel()
        var name: String?
        viewModel.output.name.sink { name = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.currencySelected(.koreanWon)

        XCTAssertEqual(name, Trip.defaultName(for: .koreanWon))
    }

    /// 自己取過名字之後，換幣別不該把名字蓋掉。
    func testACustomNameSurvivesACurrencyChange() {
        let viewModel = makeViewModel()
        var name: String?
        viewModel.output.name.sink { name = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.nameChanged("東京賞櫻")
        viewModel.input.currencySelected(.koreanWon)

        XCTAssertEqual(name, "東京賞櫻")
    }

    func testEmptyNameDisablesConfirm() {
        let viewModel = makeViewModel()
        var isEnabled: Bool?
        viewModel.output.isConfirmEnabled.sink { isEnabled = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        XCTAssertEqual(isEnabled, true)

        viewModel.input.nameChanged("   ")
        XCTAssertEqual(isEnabled, false)
    }

    // MARK: 建立

    func testCreatingATripAppendsItAndMakesItCurrent() {
        let viewModel = makeViewModel()
        var didFinish = false
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.nameChanged("東京賞櫻")
        viewModel.input.currencySelected(.koreanWon)
        viewModel.input.confirmTapped()

        XCTAssertTrue(didFinish)
        XCTAssertEqual(repository.trips.count, 1)
        XCTAssertEqual(repository.trips.first?.name, "東京賞櫻")
        XCTAssertEqual(repository.trips.first?.currency, .koreanWon)
        XCTAssertEqual(repository.currentTripID, repository.trips.first?.id, "新建的旅程要立即成為使用中")
    }

    func testCreatingKeepsExistingTrips() {
        let existing = Trip(name: "舊行程", currency: .japaneseYen)
        repository.trips = [existing]

        let viewModel = makeViewModel()
        viewModel.input.viewDidLoad()
        viewModel.input.nameChanged("新行程")
        viewModel.input.confirmTapped()

        XCTAssertEqual(repository.trips.map(\.name), ["舊行程", "新行程"])
    }

    // MARK: 編輯

    func testEditingUpdatesInPlaceWithoutChangingTheCurrentTrip() {
        let trip = Trip(name: "舊名稱", currency: .japaneseYen)
        let other = Trip(name: "其他", currency: .koreanWon)
        repository.trips = [trip, other]
        repository.currentTripID = other.id

        let viewModel = makeViewModel(editing: trip)
        viewModel.input.viewDidLoad()
        viewModel.input.nameChanged("新名稱")
        viewModel.input.currencySelected(.koreanWon)
        viewModel.input.confirmTapped()

        XCTAssertEqual(repository.trips.first?.name, "新名稱")
        XCTAssertEqual(repository.trips.first?.currency, .koreanWon)
        XCTAssertEqual(repository.trips.count, 2, "編輯不該新增旅程")
        XCTAssertEqual(repository.currentTripID, other.id, "編輯不該改變使用中的旅程")
    }

    func testEditingPrefillsTheExistingValues() {
        let trip = Trip(name: "東京賞櫻", currency: .koreanWon)
        repository.trips = [trip]

        let viewModel = makeViewModel(editing: trip)
        var name: String?
        var currency: Currency?
        viewModel.output.name.sink { name = $0 }.store(in: &cancellables)
        viewModel.output.selectedCurrency.sink { currency = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(name, "東京賞櫻")
        XCTAssertEqual(currency, .koreanWon)
    }

    func testSaveFailureReportsErrorAndDoesNotFinish() {
        repository.saveError = StubError.failure
        let viewModel = makeViewModel()
        var didFinish = false
        var message: String?
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        viewModel.input.confirmTapped()

        XCTAssertFalse(didFinish)
        XCTAssertEqual(message, "旅程儲存失敗，請再試一次")
    }
}

// MARK: - 專案清單

final class TripListViewModelTests: XCTestCase {

    private var repository: TripRepositoryStub!
    private var contentStore: TripContentStoreStub!
    private var viewModel: TripListViewModel!
    private var cancellables: Set<AnyCancellable>!

    private let older = Trip(
        name: "去年日本", currency: .japaneseYen,
        createdAt: Date(timeIntervalSince1970: 1_000_000)
    )
    private let newer = Trip(
        name: "今年韓國", currency: .koreanWon,
        createdAt: Date(timeIntervalSince1970: 2_000_000)
    )

    override func setUp() {
        super.setUp()
        repository = TripRepositoryStub(trips: [older, newer], currentTripID: older.id)
        contentStore = TripContentStoreStub()
        viewModel = TripListViewModel(repository: repository, contentStore: contentStore)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        contentStore = nil
        repository = nil
        super.tearDown()
    }

    func testTripsAreListedNewestFirst() {
        var items: [TripListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewWillAppear()

        XCTAssertEqual(items.map(\.name), ["今年韓國", "去年日本"])
    }

    func testTheCurrentTripIsMarked() {
        var items: [TripListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewWillAppear()

        XCTAssertEqual(items.first?.isCurrent, false, "今年韓國不是使用中")
        XCTAssertEqual(items.last?.isCurrent, true, "去年日本是使用中")
    }

    func testDetailShowsCurrencyAndCreationDate() {
        var items: [TripListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.viewWillAppear()

        XCTAssertEqual(items.first?.detail, "韓幣　建立於 1970/1/24")
    }

    func testSelectingATripMakesItCurrent() {
        var didSelect = false
        viewModel.output.didSelectTrip.sink { didSelect = true }.store(in: &cancellables)

        viewModel.input.viewWillAppear()
        viewModel.input.selectTrip(at: 0)

        XCTAssertTrue(didSelect)
        XCTAssertEqual(repository.currentTripID, newer.id)
    }

    // MARK: 刪除

    func testDeletingRemovesTheTripAndItsContent() {
        viewModel.input.viewWillAppear()
        viewModel.input.deleteTrip(at: 0)

        XCTAssertEqual(repository.trips.map(\.name), ["去年日本"])
        XCTAssertEqual(contentStore.removedTripIDs, [newer.id], "清單與照片要一併刪除")
    }

    /// 刪掉正在使用的專案時，要自動改用剩下最新的一個，
    /// 否則換算頁會找不到幣別。
    func testDeletingTheCurrentTripSelectsAnother() {
        viewModel.input.viewWillAppear()
        viewModel.input.deleteTrip(at: 1)

        XCTAssertEqual(repository.currentTripID, newer.id)
    }

    func testDeletingTheLastTripLeavesNoCurrentTrip() {
        repository.trips = [older]
        repository.currentTripID = older.id
        viewModel.input.viewWillAppear()

        viewModel.input.deleteTrip(at: 0)

        XCTAssertTrue(repository.trips.isEmpty)
        XCTAssertNil(repository.currentTripID)
    }

    /// 存檔失敗時要把專案放回去，畫面不能顯示已刪除但檔案還在。
    func testDeleteFailureRestoresTheTrip() {
        viewModel.input.viewWillAppear()
        repository.saveError = StubError.failure
        var items: [TripListItem] = []
        viewModel.output.items.sink { items = $0 }.store(in: &cancellables)

        viewModel.input.deleteTrip(at: 0)

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(contentStore.removedTripIDs.isEmpty, "存檔失敗就不該刪內容")
    }

    func testOutOfRangeIndexesAreIgnored() {
        viewModel.input.viewWillAppear()

        viewModel.input.selectTrip(at: 99)
        viewModel.input.deleteTrip(at: -1)
        viewModel.input.editTrip(at: 99)

        XCTAssertEqual(repository.trips.count, 2)
    }

    func testRoutes() {
        var routes: [TripListRoute] = []
        viewModel.output.route.sink { routes.append($0) }.store(in: &cancellables)

        viewModel.input.viewWillAppear()
        viewModel.input.createTapped()
        viewModel.input.editTrip(at: 0)

        XCTAssertEqual(routes, [.createTrip, .editTrip(newer)])
    }
}

// MARK: - 預設名稱

final class TripDefaultNameTests: XCTestCase {

    func testDefaultNameCombinesCurrencyAndDate() {
        let date = Date(timeIntervalSince1970: 1_757_000_000) // 2025/9/4

        XCTAssertEqual(Trip.defaultName(for: .japaneseYen, on: date), "日幣 9/4")
        XCTAssertEqual(Trip.defaultName(for: .koreanWon, on: date), "韓幣 9/4")
    }
}
