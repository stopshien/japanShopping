//
//  CardListCell.swift
//  japanShopping
//

import UIKit

final class CardListCell: UITableViewCell {

    static let reuseIdentifier = "CardListCell"

    private enum Constants {
        static let badgeInsetX: CGFloat = 10
        static let badgeInsetY: CGFloat = 4
        static let badgeRadius: CGFloat = 10
    }

    private let nameLabel = AppView.label(font: AppStyle.Font.bodyEmphasis)
    private let limitLabel = AppView.label(font: AppStyle.Font.caption, color: AppColor.textSecondary)

    private let percentBadge: UILabel = {
        let label = AppView.label(font: AppStyle.Font.label, color: .white, alignment: .center)
        label.backgroundColor = AppColor.accent
        label.layer.cornerRadius = Constants.badgeRadius
        label.clipsToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
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

    // MARK: - Setup

    private func setupViews() {
        backgroundColor = AppColor.surface
        selectionStyle = .none

        contentView.addSubview(nameLabel)
        contentView.addSubview(percentBadge)
        contentView.addSubview(limitLabel)
    }

    private func setupConstraints() {
        let inset = AppStyle.Spacing.normal
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppStyle.Spacing.tight + 4),
            nameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: percentBadge.leadingAnchor, constant: -AppStyle.Spacing.tight
            ),

            percentBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            percentBadge.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),

            limitLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            limitLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            limitLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            limitLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -(AppStyle.Spacing.tight + 4)
            )
        ])
    }

    // MARK: - Configuration

    func configure(with item: CardListItem) {
        nameLabel.text = item.name
        limitLabel.text = item.limitDescription
        percentBadge.text = "  \(item.percentBadge)  "
    }
}
