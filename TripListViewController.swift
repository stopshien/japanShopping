//
//  TripListViewController.swift
//  japanShopping
//

import Combine
import UIKit

/// 專案清單。點選切換使用中的專案，右上角新增，向左滑刪除。
final class TripListViewController: UIViewController {

    private enum Constants {
        static let estimatedRowHeight: CGFloat = 68
    }

    /// 切換專案後呼叫，讓換算頁重新載入幣別與清單。
    var onTripChanged: (() -> Void)?

    private let viewModel: TripListViewModelType
    private let factory: ScreenFactory
    private var cancellables = Set<AnyCancellable>()
    private var items: [TripListItem] = []

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = Constants.estimatedRowHeight
        tableView.backgroundColor = .clear
        tableView.separatorColor = AppColor.separator
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let emptyStateLabel = AppView.label(
        "還沒有任何旅程\n點右上角的加號建立一個",
        font: AppStyle.Font.body,
        color: AppColor.textSecondary,
        alignment: .center
    )

    // MARK: - Init

    init(viewModel: TripListViewModelType, factory: ScreenFactory) {
        self.viewModel = viewModel
        self.factory = factory
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        bindViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.input.viewWillAppear()
    }

    // MARK: - Setup

    private func setupViews() {
        title = "我的旅程"
        view.backgroundColor = AppColor.brand

        navigationItem.rightBarButtonItem = AppView.barButton(
            systemImage: "plus",
            accessibilityLabel: "新增旅程",
            target: self,
            action: #selector(createTapped)
        )

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(TripListCell.self, forCellReuseIdentifier: TripListCell.reuseIdentifier)

        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: AppStyle.Spacing.loose
            ),
            emptyStateLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -AppStyle.Spacing.loose
            )
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.items = items
                self?.tableView.reloadData()
                self?.emptyStateLabel.isHidden = !items.isEmpty
            }
            .store(in: &cancellables)

        viewModel.output.didSelectTrip
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.onTripChanged?()
                self?.navigationController?.popViewController(animated: true)
            }
            .store(in: &cancellables)

        viewModel.output.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.presentError(message)
            }
            .store(in: &cancellables)

        viewModel.output.route
            .receive(on: DispatchQueue.main)
            .sink { [weak self] route in
                self?.navigate(to: route)
            }
            .store(in: &cancellables)
    }

    // MARK: - Navigation

    private func navigate(to route: TripListRoute) {
        let controller: UIViewController
        switch route {
        case .createTrip:
            controller = factory.makeTripEditor(editing: nil) { [weak self] in
                // 新專案會直接成為使用中的專案。
                self?.onTripChanged?()
            }
        case .editTrip(let trip):
            controller = factory.makeTripEditor(editing: trip) { [weak self] in
                self?.onTripChanged?()
            }
        }
        navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: - Actions

    @objc private func createTapped() {
        viewModel.input.createTapped()
    }

    // MARK: - Private

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension TripListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TripListCell.reuseIdentifier, for: indexPath)
        if let tripCell = cell as? TripListCell, items.indices.contains(indexPath.row) {
            tripCell.configure(with: items[indexPath.row])
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension TripListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.input.selectTrip(at: indexPath.row)
    }

    /// 右側的 ⓘ 進入編輯，與「點列＝切換專案」分開，避免誤觸。
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        viewModel.input.editTrip(at: indexPath.row)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, items.indices.contains(indexPath.row) else { return }
        confirmDelete(at: indexPath.row)
    }

    /// 刪除專案會連同購物清單與照片一起消失，而且無法復原，所以先確認。
    private func confirmDelete(at index: Int) {
        let name = items[index].name
        let alert = UIAlertController(
            title: "刪除「\(name)」？",
            message: "這個旅程的消費紀錄與照片會一併刪除，無法復原。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "刪除", style: .destructive) { [weak self] _ in
            self?.viewModel.input.deleteTrip(at: index)
            self?.onTripChanged?()
        })
        present(alert, animated: true)
    }
}
