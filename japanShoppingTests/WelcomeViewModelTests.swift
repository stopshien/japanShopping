//
//  WelcomeViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

final class TripRepositoryStub: TripRepository {

    var trips: [Trip]
    var currentTripID: UUID?
    var loadError: Error?
    var saveError: Error?
    private(set) var saveCallCount = 0

    init(trips: [Trip] = [], currentTripID: UUID? = nil) {
        self.trips = trips
        self.currentTripID = currentTripID
    }

    func load() throws -> [Trip] {
        if let loadError { throw loadError }
        return trips
    }

    func save(_ trips: [Trip]) throws {
        saveCallCount += 1
        if let saveError { throw saveError }
        self.trips = trips
    }

    func loadCurrentTripID() -> UUID? { currentTripID }
    func saveCurrentTripID(_ id: UUID?) { currentTripID = id }
}

final class TripContentStoreStub: TripContentStore {

    var repositories: [UUID: ShoppingListRepositoryStub] = [:]
    private(set) var removedTripIDs: [UUID] = []

    func shoppingListRepository(for tripID: UUID) -> ShoppingListRepository {
        if let existing = repositories[tripID] { return existing }
        let created = ShoppingListRepositoryStub()
        repositories[tripID] = created
        return created
    }

    func removeContent(of tripID: UUID) {
        removedTripIDs.append(tripID)
        repositories[tripID] = nil
    }
}

final class UserProfileRepositoryStub: UserProfileRepository {

    var storedProfile: UserProfile?
    var saveError: Error?
    private(set) var saveCallCount = 0

    init(storedProfile: UserProfile? = nil) {
        self.storedProfile = storedProfile
    }

    func load() -> UserProfile? { storedProfile }

    func save(_ profile: UserProfile) throws {
        saveCallCount += 1
        if let saveError { throw saveError }
        storedProfile = profile
    }
}

final class WelcomeViewModelTests: XCTestCase {

    private var viewModel: WelcomeViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        viewModel = WelcomeViewModel()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        super.tearDown()
    }

    func testStartIsDisabledUntilANameIsEntered() {
        var isEnabled: Bool?
        viewModel.output.isStartEnabled.sink { isEnabled = $0 }.store(in: &cancellables)

        XCTAssertEqual(isEnabled, false)

        viewModel.input.nameChanged("Angus")

        XCTAssertEqual(isEnabled, true)
    }

    func testWhitespaceOnlyNameDoesNotEnableStart() {
        var isEnabled: Bool?
        viewModel.output.isStartEnabled.sink { isEnabled = $0 }.store(in: &cancellables)

        viewModel.input.nameChanged("   \n ")

        XCTAssertEqual(isEnabled, false)
    }

    /// 歡迎頁不負責儲存，只把名字交給下一步；
    /// 引導流程全部完成才寫入，中途離開不會留下半套資料。
    func testNameIsTrimmedBeforeBeingPassedOn() {
        var passedName: String?
        viewModel.output.didFinish.sink { passedName = $0 }.store(in: &cancellables)

        viewModel.input.nameChanged("  Angus  ")
        viewModel.input.startTapped()

        XCTAssertEqual(passedName, "Angus")
    }

    func testStartIsIgnoredWithoutAName() {
        var didFinish = false
        viewModel.output.didFinish.sink { _ in didFinish = true }.store(in: &cancellables)

        viewModel.input.startTapped()

        XCTAssertFalse(didFinish)
    }
}

// MARK: - 儲存實作

final class UserDefaultsUserProfileRepositoryTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var repository: UserDefaultsUserProfileRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "test.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        repository = UserDefaultsUserProfileRepository(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        repository = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    /// 首次啟動的判定就是「讀不到資料」，這個行為必須成立。
    func testLoadReturnsNilBeforeAnythingIsSaved() {
        XCTAssertNil(repository.load())
    }

    func testSaveThenLoadReturnsTheSameProfile() throws {
        let profile = UserProfile(name: "Angus")

        try repository.save(profile)

        XCTAssertEqual(repository.load(), profile)
    }

    func testSavingAgainReplacesThePreviousProfile() throws {
        try repository.save(UserProfile(name: "Angus"))
        try repository.save(UserProfile(name: "庭鋒"))

        XCTAssertEqual(repository.load()?.name, "庭鋒")
    }
}
