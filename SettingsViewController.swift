//
//  SettingsViewController.swift
//  japanShopping
//

import Combine
import UIKit

/// 設定選項的列表。每一列只顯示名稱，點選後進入對應的功能頁。
final class SettingsViewController: UIViewController {

    private enum Constants {
        static let cellIdentifier = "SettingsCell"
    }

    private let viewModel: SettingsViewModelType
    private let factory: ScreenFactory
    private var cancellables = Set<AnyCancellable>()

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = .clear
        tableView.separatorColor = AppColor.separator
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    // MARK: - Init

    init(viewModel: SettingsViewModelType, factory: ScreenFactory) {
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

    // MARK: - Setup

    private func setupViews() {
        title = "設定"
        view.backgroundColor = AppColor.brand

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.cellIdentifier)

        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.route
            .receive(on: DispatchQueue.main)
            .sink { [weak self] row in
                self?.navigate(to: row)
            }
            .store(in: &cancellables)
    }

    // MARK: - Navigation

    private func navigate(to row: SettingsRow) {
        let controller: UIViewController
        switch row {
        case .profile:
            controller = factory.makeProfile()
        case .cards:
            controller = factory.makeCardList()
        }
        navigationController?.pushViewController(controller, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.output.rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.cellIdentifier, for: indexPath)
        guard viewModel.output.rows.indices.contains(indexPath.row) else { return cell }
        let row = viewModel.output.rows[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.textProperties.font = AppStyle.Font.body
        content.textProperties.color = AppColor.textPrimary
        content.image = UIImage(systemName: row.systemImage)
        content.imageProperties.tintColor = AppColor.accent
        cell.contentConfiguration = content
        cell.backgroundColor = AppColor.surface
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.input.rowSelected(at: indexPath.row)
    }
}
