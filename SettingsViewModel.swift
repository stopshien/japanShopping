//
//  SettingsViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

/// 設定頁的每一列。點選後進入對應的功能頁。
enum SettingsRow: CaseIterable, Equatable {
    case profile
    case cards

    var title: String {
        switch self {
        case .profile:
            return "個人資料"
        case .cards:
            return "管理信用卡"
        }
    }

    var systemImage: String {
        switch self {
        case .profile:
            return "person"
        case .cards:
            return "creditcard"
        }
    }
}

protocol SettingsViewModelType {
    var input: SettingsViewModelInput { get }
    var output: SettingsViewModelOutput { get }
}

protocol SettingsViewModelInput {
    func rowSelected(at index: Int)
}

protocol SettingsViewModelOutput {
    var rows: [SettingsRow] { get }
    var route: AnyPublisher<SettingsRow, Never> { get }
}

// MARK: - ViewModel

final class SettingsViewModel: SettingsViewModelType {

    let rows = SettingsRow.allCases

    private let routeSubject = PassthroughSubject<SettingsRow, Never>()

    var input: SettingsViewModelInput { self }
    var output: SettingsViewModelOutput { self }
}

// MARK: - SettingsViewModelInput

extension SettingsViewModel: SettingsViewModelInput {

    func rowSelected(at index: Int) {
        guard rows.indices.contains(index) else { return }
        routeSubject.send(rows[index])
    }
}

// MARK: - SettingsViewModelOutput

extension SettingsViewModel: SettingsViewModelOutput {

    var route: AnyPublisher<SettingsRow, Never> { routeSubject.eraseToAnyPublisher() }
}
