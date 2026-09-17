//
//  CardListViewController.swift
//  japanShopping
//

import Combine
import UIKit

/// 取代原本 storyboard 上的 EditCardsTableViewController。
final class CardListViewController: UIViewController {

    private enum Constants {
        static let estimatedRowHeight: CGFloat = 68
    }

    /// 按下完成並返回前呼叫，讓上一頁知道資料已變更。
    var onFinish: (() -> Void)?

    private let viewModel: CardListViewModelType
    private var cancellables = Set<AnyCancellable>()
    private var items: [CardListItem] = []

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = Constants.estimatedRowHeight
        tableView.backgroundColor = .clear
        tableView.separatorColor = AppColor.separator
        tableView.separatorInset = UIEdgeInsets(
            top: 0, left: AppStyle.Spacing.normal, bottom: 0, right: AppStyle.Spacing.normal
        )
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let finishButton = AppView.primaryButton(title: "完成")

    private let emptyStateLabel = AppView.label(
        "尚未新增任何信用卡\n回到上一頁的下拉選單即可新增",
        font: AppStyle.Font.body,
        color: AppColor.textSecondary,
        alignment: .center
    )

    init(viewModel: CardListViewModelType) {
        self.viewModel = viewModel
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
        viewModel.input.viewDidLoad()
    }

    // MARK: - Setup

    private func setupViews() {
        title = "管理信用卡"
        view.backgroundColor = AppColor.brand

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CardListCell.self, forCellReuseIdentifier: CardListCell.reuseIdentifier)

        finishButton.addTarget(self, action: #selector(finishTapped), for: .touchUpInside)

        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        view.addSubview(finishButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: finishButton.topAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: AppStyle.Spacing.loose
            ),
            emptyStateLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -AppStyle.Spacing.loose
            ),

            finishButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppStyle.Spacing.normal),
            finishButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppStyle.Spacing.normal),
            finishButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppStyle.Spacing.normal
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
                self?.finishButton.isHidden = items.isEmpty
            }
            .store(in: &cancellables)

        viewModel.output.errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.presentError(message)
            }
            .store(in: &cancellables)

        viewModel.output.didFinish
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.onFinish?()
                self?.navigationController?.popViewController(animated: true)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func finishTapped() {
        viewModel.input.finishTapped()
    }

    // MARK: - Private

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension CardListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CardListCell.reuseIdentifier, for: indexPath)
        if let cardCell = cell as? CardListCell, items.indices.contains(indexPath.row) {
            cardCell.configure(with: items[indexPath.row])
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension CardListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        viewModel.input.deleteCard(at: indexPath.row)
    }
}

