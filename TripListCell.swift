//
//  TripListCell.swift
//  japanShopping
//

import UIKit

final class TripListCell: UITableViewCell {

    static let reuseIdentifier = "TripListCell"

    /// 右側的編輯按鈕。系統的 detailButton 只能是 ⓘ，換成鉛筆要自己放 accessoryView，
    /// 因此點擊也要自己往外傳（accessoryButtonTapped 只對系統的 ⓘ 有效）。
    var onEdit: (() -> Void)?

    private lazy var editButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(
            UIImage(
                systemName: "square.and.pencil",
                withConfiguration: UIImage.SymbolConfiguration(textStyle: .body)
            ),
            for: .normal
        )
        button.tintColor = AppColor.accent
        button.accessibilityLabel = "編輯旅程"
        button.sizeToFit()
        button.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        return button
    }()

    private let nameLabel = AppView.label(font: AppStyle.Font.bodyEmphasis)
    private let detailLabel = AppView.label(font: AppStyle.Font.caption, color: AppColor.textSecondary)

    private let currentMarkView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        imageView.tintColor = AppColor.accent
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Actions

    @objc private func editTapped() {
        onEdit?()
    }

    // MARK: - Setup

    private func setupViews() {
        backgroundColor = AppColor.surface
        accessoryView = editButton

        contentView.addSubview(nameLabel)
        contentView.addSubview(currentMarkView)
        contentView.addSubview(detailLabel)
    }

    private func setupConstraints() {
        let inset = AppStyle.Spacing.normal
        NSLayoutConstraint.activate([
            currentMarkView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            currentMarkView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            currentMarkView.widthAnchor.constraint(equalToConstant: 22),
            currentMarkView.heightAnchor.constraint(equalToConstant: 22),

            nameLabel.leadingAnchor.constraint(
                equalTo: currentMarkView.trailingAnchor, constant: AppStyle.Spacing.tight + 4
            ),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppStyle.Spacing.tight + 4),

            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            detailLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -(AppStyle.Spacing.tight + 4)
            )
        ])
    }

    // MARK: - Configuration

    func configure(with item: TripListItem) {
        nameLabel.text = item.name
        detailLabel.text = item.detail
        currentMarkView.isHidden = !item.isCurrent
        accessibilityLabel = item.isCurrent ? "\(item.name)，使用中。\(item.detail)" : "\(item.name)。\(item.detail)"
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onEdit = nil
    }
}
