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
        static let estimatedRowHeight: CGFloat = 130
        static let horizontalInset: CGFloat = AppStyle.Spacing.normal
    }

    private let viewModel: ShoppingListViewModelType
    private let factory: ScreenFactory
    private let allowsBack: Bool
    private var cancellables = Set<AnyCancellable>()
    private var items: [ShoppingListItem] = []

    private let tableView: UITableView = {
        // 圓角卡片清單，和我的旅程、設定同一套視覺；整片白底會和其他頁不一致，
        // 筆數少時還會在畫面中間留下一條白綠分界。
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        // 大字級時列高要跟著內容長高。
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = Constants.estimatedRowHeight
        tableView.backgroundColor = .clear
        tableView.separatorColor = AppColor.separator
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    /// 這頁最重要的摘要，用大字。
    private let totalAmountLabel: UILabel = {
        let label = AppView.label(font: AppStyle.Font.resultNumber)
        // 金額不換行，位數多時縮小字級，否則「NT$ 1,165」會斷成兩行。
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()
    private let totalSummaryLabel = AppView.label(font: AppStyle.Font.caption, color: AppColor.textSecondary)

    /// 底部摘要做成浮起的卡片，和清單、其他頁的卡片語言一致；
    /// 直接坐在綠色背景上會顯得單薄。
    private let bottomCard = AppView.card()

    private let emptyStateLabel = AppView.label(
        "還沒有任何消費紀錄\n回上一頁輸入價格就能記一筆",
        font: AppStyle.Font.body,
        color: AppColor.textSecondary,
        alignment: .center
    )

    init(viewModel: ShoppingListViewModelType, factory: ScreenFactory, allowsBack: Bool) {
        self.viewModel = viewModel
        self.factory = factory
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
        title = "消費紀錄"
        navigationItem.hidesBackButton = !allowsBack
        // 新增消費後進來時沒有返回鍵，由右上角「完成」回到首頁。
        if !allowsBack {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "完成", style: .done, target: self, action: #selector(doneTapped)
            )
        }
        view.backgroundColor = AppColor.brand

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ShoppingListCell.self, forCellReuseIdentifier: ShoppingListCell.reuseIdentifier)

        totalAmountLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        let bottomStack = AppView.cardStack(in: bottomCard, spacing: 0)
        [totalAmountLabel, totalSummaryLabel].forEach(bottomStack.addArrangedSubview)

        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        view.addSubview(bottomCard)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomCard.topAnchor, constant: -AppStyle.Spacing.tight),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: AppStyle.Spacing.loose
            ),
            emptyStateLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -AppStyle.Spacing.loose
            ),

            bottomCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.horizontalInset),
            bottomCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.horizontalInset),
            bottomCard.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppStyle.Spacing.tight
            )
        ])
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.output.items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }
                self.items = items
                self.tableView.reloadData()
                self.emptyStateLabel.isHidden = !items.isEmpty
            }
            .store(in: &cancellables)

        viewModel.output.totalAmount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.totalAmountLabel.text = text
            }
            .store(in: &cancellables)

        viewModel.output.totalSummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.totalSummaryLabel.text = text
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

        viewModel.output.editRequest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request in
                self?.showEditor(for: request)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        viewModel.input.doneTapped()
    }

    // MARK: - Navigation

    private func showEditor(for request: ShoppingListEditRequest) {
        let controller = factory.makeItemEditor(item: request.item, photoData: request.photoData) { [weak self] edit in
            self?.viewModel.input.itemEdited(at: request.index, edit)
        }
        navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: - Private

    /// 刪除會立即寫檔且無法復原，先確認；取消時收起滑出的刪除鍵。
    private func confirmDelete(at index: Int) {
        let name = items.indices.contains(index) ? items[index].productName : ""
        let alert = UIAlertController(
            title: "刪除這筆消費？",
            message: name.isEmpty ? "刪除後無法復原。" : "「\(name)」刪除後無法復原。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.tableView.setEditing(false, animated: true)
        })
        alert.addAction(UIAlertAction(title: "刪除", style: .destructive) { [weak self] _ in
            self?.viewModel.input.deleteItem(at: index)
        })
        present(alert, animated: true)
    }

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
        confirmDelete(at: indexPath.row)
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        "刪除"
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.input.itemSelected(at: indexPath.row)
    }
}
