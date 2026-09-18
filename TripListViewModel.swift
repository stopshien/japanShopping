//
//  TripListViewModel.swift
//  japanShopping
//

import Combine
import Foundation

// MARK: - Contract

struct TripListItem: Equatable {
    let id: UUID
    let name: String
    let detail: String
    let isCurrent: Bool
}

enum TripListRoute: Equatable {
    case createTrip
    case editTrip(Trip)
}

protocol TripListViewModelType {
    var input: TripListViewModelInput { get }
    var output: TripListViewModelOutput { get }
}

protocol TripListViewModelInput {
    func viewWillAppear()
    func selectTrip(at index: Int)
    func editTrip(at index: Int)
    func deleteTrip(at index: Int)
    func createTapped()
}

protocol TripListViewModelOutput {
    var items: AnyPublisher<[TripListItem], Never> { get }
    var route: AnyPublisher<TripListRoute, Never> { get }
    var errorMessage: AnyPublisher<String, Never> { get }
    var didSelectTrip: AnyPublisher<Void, Never> { get }
}

// MARK: - ViewModel

final class TripListViewModel: TripListViewModelType {

    private let repository: TripRepository
    private let contentStore: TripContentStore

    private var trips: [Trip] = []

    private let itemsSubject = CurrentValueSubject<[TripListItem], Never>([])
    private let routeSubject = PassthroughSubject<TripListRoute, Never>()
    private let errorMessageSubject = PassthroughSubject<String, Never>()
    private let didSelectTripSubject = PassthroughSubject<Void, Never>()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }()

    init(repository: TripRepository, contentStore: TripContentStore) {
        self.repository = repository
        self.contentStore = contentStore
    }

    var input: TripListViewModelInput { self }
    var output: TripListViewModelOutput { self }

    // MARK: - Private

    private func publish() {
        let currentID = repository.loadCurrentTripID()
        itemsSubject.send(trips.map { trip in
            TripListItem(
                id: trip.id,
                name: trip.name,
                detail: "\(trip.currency.title)　建立於 \(dateFormatter.string(from: trip.createdAt))",
                isCurrent: trip.id == currentID
            )
        })
    }
}

// MARK: - TripListViewModelInput

extension TripListViewModel: TripListViewModelInput {

    /// 建立或編輯專案後返回這一頁都要重新載入，所以綁在 viewWillAppear。
    func viewWillAppear() {
        do {
            trips = try repository.load().sorted { $0.createdAt > $1.createdAt }
        } catch {
            trips = []
            errorMessageSubject.send("旅程讀取失敗")
        }
        publish()
    }

    func selectTrip(at index: Int) {
        guard trips.indices.contains(index) else { return }
        repository.saveCurrentTripID(trips[index].id)
        publish()
        didSelectTripSubject.send(())
    }

    func editTrip(at index: Int) {
        guard trips.indices.contains(index) else { return }
        routeSubject.send(.editTrip(trips[index]))
    }

    /// 刪除專案會一併清掉它的購物清單與照片，而且立即生效 ——
    /// 與清單內的刪除不同，這裡沒有「稍後確認」的步驟。
    func deleteTrip(at index: Int) {
        guard trips.indices.contains(index) else { return }
        let removed = trips.remove(at: index)

        do {
            try repository.save(trips)
        } catch {
            trips.insert(removed, at: index)
            errorMessageSubject.send("旅程刪除失敗，請再試一次")
            publish()
            return
        }

        contentStore.removeContent(of: removed.id)

        // 刪掉的正好是使用中的專案時，改用剩下最新的一個。
        if repository.loadCurrentTripID() == removed.id {
            repository.saveCurrentTripID(trips.first?.id)
        }
        publish()
    }

    func createTapped() {
        routeSubject.send(.createTrip)
    }
}

// MARK: - TripListViewModelOutput

extension TripListViewModel: TripListViewModelOutput {

    var items: AnyPublisher<[TripListItem], Never> { itemsSubject.eraseToAnyPublisher() }
    var route: AnyPublisher<TripListRoute, Never> { routeSubject.eraseToAnyPublisher() }
    var errorMessage: AnyPublisher<String, Never> { errorMessageSubject.eraseToAnyPublisher() }
    var didSelectTrip: AnyPublisher<Void, Never> { didSelectTripSubject.eraseToAnyPublisher() }
}
