//
//  CardListViewController.swift
//  japanShopping
//

import Combine
import UIKit

/// 取代原本 storyboard 上的 EditCardsTableViewController。
final class CardListViewController: UIViewController {

    private enum Constants {
        static let rowHeight: CGFloat = 119
        static let footerHeight: CGFloat = 44
        static let cellReuseIdentifier = "CardListCell"
        static let textColor = UIColor(displayP3Red: 0.7567, green: 0.7892, blue: 0.5646, alpha: 1)
    }

    /// 編輯完成並返回前呼叫，讓上一頁知道資料已變更。
    var onFinish: (() -> Void)?

    private let viewModel: CardListViewModelType
    private var cancellables = Set<AnyCancellable>()
    private var items: [CardListItem] = []

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.rowHeight = Constants.rowHeight
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let finishButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "編輯完成"
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

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
        title = "編輯信用卡"
        view.backgroundColor = .systemBackground

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CardListCell.self, forCellReuseIdentifier: Constants.cellReuseIdentifier)

        finishButton.addTarget(self, action: #selector(finishTapped), for: .touchUpInside)

        view.addSubview(tableView)
        view.addSubview(finishButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: finishButton.topAnchor),

            finishButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            finishButton.heightAnchor.constraint(equalToConstant: Constants.footerHeight),
            finishButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.items = items
                self?.tableView.reloadData()
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
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.cellReuseIdentifier, for: indexPath)
        if let cardCell = cell as? CardListCell, items.indices.contains(indexPath.row) {
            cardCell.configure(with: items[indexPath.row], textColor: Constants.textColor)
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

// MARK: - CardListCell

private final class CardListCell: UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(with item: CardListItem, textColor: UIColor) {
        var content = defaultContentConfiguration()
        content.text = item.name
        content.secondaryText = item.feedbackDescription
        content.textProperties.font = .boldSystemFont(ofSize: 17)
        content.textProperties.color = textColor
        content.secondaryTextProperties.font = .boldSystemFont(ofSize: 15)
        content.secondaryTextProperties.color = textColor
        contentConfiguration = content
    }
}
