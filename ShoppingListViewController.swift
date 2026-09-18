//
//  ShoppingListViewController.swift
//  japanShopping
//
//  取代原本 storyboard 上的 ListViewController。
//

import Combine
import UIKit

final class ShoppingListViewController: UIViewController {

    private enum Constants {
        static let rowHeight: CGFloat = 130
        static let horizontalInset: CGFloat = AppStyle.Spacing.normal
        static let bottomBarHeight: CGFloat = 56
    }

    private let viewModel: ShoppingListViewModelType
    private let allowsBack: Bool
    private var cancellables = Set<AnyCancellable>()
    private var items: [ShoppingListItem] = []

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.rowHeight = Constants.rowHeight
        tableView.backgroundColor = .clear
        tableView.separatorColor = AppColor.separator
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let totalSpendLabel = AppView.label(font: AppStyle.Font.bodyEmphasis)

    private let doneButton = AppView.primaryButton(title: "完成")

    init(viewModel: ShoppingListViewModelType, allowsBack: Bool) {
        self.viewModel = viewModel
        self.allowsBack = allowsBack
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !allowsBack {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }

    /// 滑動返回手勢是整個 navigation controller 共用的，離開時要還原，否則其他頁也無法滑動返回。
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    // MARK: - Setup

    private func setupViews() {
        title = "購物清單"
        navigationItem.hidesBackButton = !allowsBack
        view.backgroundColor = AppColor.brand

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ShoppingListCell.self, forCellReuseIdentifier: ShoppingListCell.reuseIdentifier)

        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        view.addSubview(tableView)
        view.addSubview(totalSpendLabel)
        view.addSubview(doneButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: totalSpendLabel.topAnchor),

            totalSpendLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.horizontalInset),
            totalSpendLabel.heightAnchor.constraint(equalToConstant: Constants.bottomBarHeight),
            totalSpendLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.horizontalInset),
            doneButton.leadingAnchor.constraint(
                greaterThanOrEqualTo: totalSpendLabel.trailingAnchor, constant: AppStyle.Spacing.normal
            ),
            doneButton.centerYAnchor.constraint(equalTo: totalSpendLabel.centerYAnchor)
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

        viewModel.output.totalSpendText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.totalSpendLabel.text = text
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
                self?.navigationController?.popToRootViewController(animated: true)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        viewModel.input.doneTapped()
    }

    // MARK: - Private

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ShoppingListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ShoppingListCell.reuseIdentifier, for: indexPath)
        if let shoppingCell = cell as? ShoppingListCell, items.indices.contains(indexPath.row) {
            shoppingCell.configure(with: items[indexPath.row])
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ShoppingListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        viewModel.input.deleteItem(at: indexPath.row)
    }
}
