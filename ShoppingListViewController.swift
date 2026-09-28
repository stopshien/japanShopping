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
        static let sectionHeaderIdentifier = "ShoppingListSectionHeader"
        static let estimatedRowHeight: CGFloat = 130
        static let horizontalInset: CGFloat = AppStyle.Spacing.normal
    }

    private let viewModel: ShoppingListViewModelType
    private let factory: ScreenFactory
    private let allowsBack: Bool
    private var cancellables = Set<AnyCancellable>()
    private var sections: [ShoppingListSection] = []

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

    /// 清單右上角的日期排序切換，只是一個小的文字按鈕，不搶清單的注意力。
    private let sortButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.attributedTitle = AttributedString(
            "日期", attributes: AttributeContainer([.font: AppStyle.Font.label])
        )
        configuration.image = UIImage(
            systemName: "arrow.up.arrow.down",
            withConfiguration: UIImage.SymbolConfiguration(font: AppStyle.Font.caption)
        )
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 4
        configuration.baseForegroundColor = AppColor.accent
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: AppStyle.Spacing.tight, leading: 0, bottom: AppStyle.Spacing.tight, trailing: 0
        )
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = "日期排序"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

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
        tableView.register(
            UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: Constants.sectionHeaderIdentifier
        )

        totalAmountLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        let bottomStack = AppView.cardStack(in: bottomCard, spacing: 0)
        [totalAmountLabel, totalSummaryLabel].forEach(bottomStack.addArrangedSubview)

        sortButton.addTarget(self, action: #selector(sortTapped), for: .touchUpInside)

        view.addSubview(sortButton)
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        view.addSubview(bottomCard)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 和區塊標題的小計右緣對齊。
            sortButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            // insetGrouped 的卡片比清單邊距再內縮一層，標題文字又在卡片內側。
            sortButton.trailingAnchor.constraint(
                equalTo: tableView.layoutMarginsGuide.trailingAnchor, constant: -AppStyle.Spacing.normal
            ),

            tableView.topAnchor.constraint(equalTo: sortButton.bottomAnchor),
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
        viewModel.output.sections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sections in
                guard let self else { return }
                self.sections = sections
                self.tableView.reloadData()
                self.emptyStateLabel.isHidden = !sections.isEmpty
                // 沒有紀錄時排序沒有意義，收起來避免空畫面上多一個控制項。
                self.sortButton.isHidden = sections.isEmpty
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

        viewModel.output.sortOrder
            .receive(on: DispatchQueue.main)
            .sink { [weak self] order in
                self?.sortButton.accessibilityValue = order.title
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

    @objc private func sortTapped() {
        viewModel.input.sortOrderToggled()
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
    private func confirmDelete(at indexPath: IndexPath) {
        let name = item(at: indexPath)?.productName ?? ""
        let alert = UIAlertController(
            title: "刪除這筆消費？",
            message: name.isEmpty ? "刪除後無法復原。" : "「\(name)」刪除後無法復原。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.tableView.setEditing(false, animated: true)
        })
        alert.addAction(UIAlertAction(title: "刪除", style: .destructive) { [weak self] _ in
            self?.viewModel.input.deleteItem(at: indexPath)
        })
        present(alert, animated: true)
    }

    private func item(at indexPath: IndexPath) -> ShoppingListItem? {
        guard sections.indices.contains(indexPath.section),
              sections[indexPath.section].items.indices.contains(indexPath.row) else { return nil }
        return sections[indexPath.section].items[indexPath.row]
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ShoppingListViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections.indices.contains(section) ? sections[section].items.count : 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ShoppingListCell.reuseIdentifier, for: indexPath)
        if let shoppingCell = cell as? ShoppingListCell, let item = item(at: indexPath) {
            shoppingCell.configure(with: item)
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ShoppingListViewController: UITableViewDelegate {

    /// 日期在左、當天小計在右，每天一張卡片。
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard sections.indices.contains(section) else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: Constants.sectionHeaderIdentifier)
        var configuration = UIListContentConfiguration.groupedHeader()
        configuration.text = sections[section].title
        configuration.secondaryText = sections[section].subtotal
        configuration.prefersSideBySideTextAndSecondaryText = true
        configuration.textProperties.font = AppStyle.Font.labelEmphasis
        configuration.textProperties.color = AppColor.textPrimary
        configuration.secondaryTextProperties.font = AppStyle.Font.label
        configuration.secondaryTextProperties.color = AppColor.textSecondary
        header?.contentConfiguration = configuration
        return header
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        confirmDelete(at: indexPath)
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        "刪除"
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.input.itemSelected(at: indexPath)
    }
}
