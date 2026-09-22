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
        static let bottomBarHeight: CGFloat = 56
    }

    private let viewModel: ShoppingListViewModelType
    private let factory: ScreenFactory
    private let allowsBack: Bool
    private var cancellables = Set<AnyCancellable>()
    private var items: [ShoppingListItem] = []

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
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

    private lazy var totalStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [totalAmountLabel, totalSummaryLabel])
        stackView.axis = .vertical
        stackView.spacing = 0
        return stackView
    }()

    /// 底部列在綠色底上，次要按鈕的淡色底幾乎融進背景、看起來像停用，所以維持實心。
    private let doneButton = AppView.primaryButton(title: "完成並儲存")

    private let bottomBarStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.spacing = AppStyle.Spacing.normal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

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

    /// 大字級時總金額與「完成」並排會互相擠壓，改成上下排列。
    /// 專案支援 iOS 15，所以用 traitCollectionDidChange 而不是 iOS 17 的 registerForTraitChanges。
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        guard traitCollection.preferredContentSizeCategory != previous?.preferredContentSizeCategory else { return }
        updateBottomBarAxis()
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
        view.backgroundColor = AppColor.brand

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ShoppingListCell.self, forCellReuseIdentifier: ShoppingListCell.reuseIdentifier)

        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        totalAmountLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        bottomBarStackView.addArrangedSubview(totalStackView)
        bottomBarStackView.addArrangedSubview(doneButton)

        view.addSubview(tableView)
        view.addSubview(bottomBarStackView)
        updateBottomBarAxis()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomBarStackView.topAnchor),

            bottomBarStackView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: Constants.horizontalInset
            ),
            bottomBarStackView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -Constants.horizontalInset
            ),
            bottomBarStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            // 大字級時總金額會換行，底部列要能長高。
            bottomBarStackView.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.bottomBarHeight)
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

    private func updateBottomBarAxis() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        bottomBarStackView.axis = isAccessibilitySize ? .vertical : .horizontal
        bottomBarStackView.alignment = isAccessibilitySize ? .fill : .center
    }

    // MARK: - Navigation

    private func showEditor(for request: ShoppingListEditRequest) {
        let controller = factory.makeItemEditor(item: request.item, photoData: request.photoData) { [weak self] edit in
            self?.viewModel.input.itemEdited(at: request.index, edit)
        }
        navigationController?.pushViewController(controller, animated: true)
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.input.itemSelected(at: indexPath.row)
    }
}
