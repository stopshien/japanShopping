//
//  OnboardingAndSettingsTests.swift
//  japanShoppingTests
//

import Combine
import XCTest
@testable import japanShopping

// MARK: - 設定頁

final class SettingsViewModelTests: XCTestCase {

    func testRowsAreProfileThenCards() {
        let viewModel = SettingsViewModel()

        XCTAssertEqual(viewModel.output.rows.map(\.title), ["個人資料", "管理信用卡"])
    }

    func testSelectingARowRoutesToIt() {
        let viewModel = SettingsViewModel()
        var routes: [SettingsRow] = []
        let cancellable = viewModel.output.route.sink { routes.append($0) }

        viewModel.input.rowSelected(at: 0)
        viewModel.input.rowSelected(at: 1)
        viewModel.input.rowSelected(at: 99)

        XCTAssertEqual(routes, [.profile, .cards])
        cancellable.cancel()
    }
}

// MARK: - 稱呼

final class ProfileViewModelTests: XCTestCase {

    private var repository: UserProfileRepositoryStub!
    private var viewModel: ProfileViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        repository = UserProfileRepositoryStub(storedProfile: UserProfile(name: "Angus"))
        viewModel = ProfileViewModel(repository: repository)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        repository = nil
        super.tearDown()
    }

    func testViewDidLoadShowsTheStoredName() {
        var name: String?
        viewModel.output.name.sink { name = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()

        XCTAssertEqual(name, "Angus")
    }

    /// 幣別屬於專案，不在使用者設定裡。
    func testChangingNameIsSaved() {
        viewModel.input.viewDidLoad()
        viewModel.input.nameChanged("庭鋒")
        viewModel.input.saveTapped()

        XCTAssertEqual(repository.storedProfile?.name, "庭鋒")
    }

    func testEmptyNameDisablesSave() {
        var isEnabled: Bool?
        viewModel.output.isSaveEnabled.sink { isEnabled = $0 }.store(in: &cancellables)

        viewModel.input.viewDidLoad()
        XCTAssertEqual(isEnabled, true)

        viewModel.input.nameChanged("   ")
        XCTAssertEqual(isEnabled, false)
    }

    func testSaveIsIgnoredWithoutAName() {
        viewModel.input.viewDidLoad()
        viewModel.input.nameChanged("")
        viewModel.input.saveTapped()

        XCTAssertEqual(repository.storedProfile?.name, "Angus", "未儲存，原值不變")
    }
}
