//
//  WelcomeViewModelTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

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

    private var repository: UserProfileRepositoryStub!
    private var viewModel: WelcomeViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        repository = UserProfileRepositoryStub()
        viewModel = WelcomeViewModel(repository: repository)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        repository = nil
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

    func testNameIsTrimmedBeforeSaving() {
        viewModel.input.nameChanged("  Angus  ")
        viewModel.input.startTapped()

        XCTAssertEqual(repository.storedProfile, UserProfile(name: "Angus"))
    }

    func testStartSavesTheProfileAndFinishes() {
        var didFinish = false
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)

        viewModel.input.nameChanged("Angus")
        viewModel.input.startTapped()

        XCTAssertTrue(didFinish)
        XCTAssertEqual(repository.storedProfile?.name, "Angus")
    }

    func testStartIsIgnoredWithoutAName() {
        var didFinish = false
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)

        viewModel.input.startTapped()

        XCTAssertFalse(didFinish)
        XCTAssertEqual(repository.saveCallCount, 0)
    }

    func testSaveFailureReportsErrorAndDoesNotFinish() {
        repository.saveError = StubError.failure
        var didFinish = false
        var message: String?
        viewModel.output.didFinish.sink { didFinish = true }.store(in: &cancellables)
        viewModel.output.errorMessage.sink { message = $0 }.store(in: &cancellables)

        viewModel.input.nameChanged("Angus")
        viewModel.input.startTapped()

        XCTAssertFalse(didFinish)
        XCTAssertEqual(message, "設定儲存失敗，請再試一次")
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
