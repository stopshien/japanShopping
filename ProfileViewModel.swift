//
//  ProfileViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

protocol ProfileViewModelType {
    var input: ProfileViewModelInput { get }
    var output: ProfileViewModelOutput { get }
}

protocol ProfileViewModelInput {
    func viewDidLoad()
    func nameChanged(_ text: String)
    func saveTapped()
}

protocol ProfileViewModelOutput {
    var name: AnyPublisher<String, Never> { get }
    var isSaveEnabled: AnyPublisher<Bool, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didFinish: AnyPublisher<Void, Never> { get }
}

// MARK: - ViewModel

final class ProfileViewModel: ProfileViewModelType {

    private let repository: UserProfileRepository
    private var currentName = ""

    private let nameSubject = CurrentValueSubject<String, Never>("")
    private let isSaveEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didFinishSubject = PassthroughSubject<Void, Never>()

    init(repository: UserProfileRepository) {
        self.repository = repository
    }

    var input: ProfileViewModelInput { self }
    var output: ProfileViewModelOutput { self }
}

// MARK: - ProfileViewModelInput

extension ProfileViewModel: ProfileViewModelInput {

    func viewDidLoad() {
        guard let profile = repository.load() else { return }
        currentName = profile.name
        nameSubject.send(profile.name)
        isSaveEnabledSubject.send(!profile.name.isEmpty)
    }

    func nameChanged(_ text: String) {
        currentName = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaveEnabledSubject.send(!currentName.isEmpty)
    }

    func saveTapped() {
        guard !currentName.isEmpty else { return }

        do {
            try repository.save(UserProfile(name: currentName))
        } catch {
            errorMessageSubject.send("稱呼儲存失敗，請再試一次")
            return
        }
        didFinishSubject.send(())
    }
}

// MARK: - ProfileViewModelOutput

extension ProfileViewModel: ProfileViewModelOutput {

    var name: AnyPublisher<String, Never> { nameSubject.eraseToAnyPublisher() }
    var isSaveEnabled: AnyPublisher<Bool, Never> { isSaveEnabledSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didFinish: AnyPublisher<Void, Never> { didFinishSubject.eraseToAnyPublisher() }
}
