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
    var errorMessage: AnyPublisher<String, Never> { get }
    var didFinish: AnyPublisher<Void, Never> { get }
}

// MARK: - ViewModel

final class WelcomeViewModel: WelcomeViewModelType {

    private let repository: UserProfileRepository
    private var name = ""

    private let isStartEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didFinishSubject = PassthroughSubject<Void, Never>()

    init(repository: UserProfileRepository) {
        self.repository = repository
    }

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

        do {
            try repository.save(UserProfile(name: name))
        } catch {
            errorMessageSubject.send("設定儲存失敗，請再試一次")
            return
        }
        didFinishSubject.send(())
    }
}

// MARK: - WelcomeViewModelOutput

extension WelcomeViewModel: WelcomeViewModelOutput {

    var isStartEnabled: AnyPublisher<Bool, Never> { isStartEnabledSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didFinish: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }
}
