//
//  WelcomeViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

protocol WelcomeViewModelType {
    var input: WelcomeViewModelInput { get }
    var output: WelcomeViewModelOutput { get }
}

protocol WelcomeViewModelInput {
    func nameChanged(_ text: String)
    func startTapped()
}

protocol WelcomeViewModelOutput {
    var isStartEnabled: AnyPublisher<Bool, Never> { get }
    /// 帶著輸入的名字進入下一步。引導流程全部完成才會寫入設定，
    /// 中途離開不會留下半套資料。
    var didFinish: AnyPublisher<String, Never> { get }
}

// MARK: - ViewModel

final class WelcomeViewModel: WelcomeViewModelType {

    private var name = ""

    private let isStartEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let didFinishSubject = PassthroughSubject<String, Never>()

    var input: WelcomeViewModelInput { self }
    var output: WelcomeViewModelOutput { self }
}

// MARK: - WelcomeViewModelInput

extension WelcomeViewModel: WelcomeViewModelInput {

    func nameChanged(_ text: String) {
        name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isStartEnabledSubject.send(!name.isEmpty)
    }

    func startTapped() {
        guard !name.isEmpty else { return }
        didFinishSubject.send(name)
    }
}

// MARK: - WelcomeViewModelOutput

extension WelcomeViewModel: WelcomeViewModelOutput {

    var isStartEnabled: AnyPublisher<Bool, Never> { isStartEnabledSubject.eraseToAnyPublisher() }
    var didFinish: AnyPublisher<String, Never> { didFinishSubject.eraseToAnyPublisher() }
}
