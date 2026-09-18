//
//  ShoppingListCell.swift
//  japanShopping
//
//  取代原本 storyboard 上的 ListTableViewCell。
//

import UIKit

final class ShoppingListCell: UITableViewCell {

    static let reuseIdentifier = "ShoppingListCell"

    private enum Constants {
        static let photoWidth: CGFloat = 100
        static let photoInset: CGFloat = AppStyle.Spacing.normal
        static let verticalInset: CGFloat = AppStyle.Spacing.tight + 4
        static let textLeading: CGFloat = 14
        static let nameFontSize: CGFloat = 25
        static let detailFontSize: CGFloat = 20
    }

    private let shopPhoto: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = AppStyle.Radius.control
        imageView.backgroundColor = AppColor.accentSoft
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let productNameLabel = AppView.label(font: AppStyle.Font.title)
    private let priceLabel = AppView.label(font: AppStyle.Font.bodyEmphasis)
    private let payTypeLabel = AppView.label(font: AppStyle.Font.body, color: AppColor.textSecondary)

    private let textStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
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
        // 點選一筆可以編輯。
        accessoryType = .disclosureIndicator
        [productNameLabel, priceLabel, payTypeLabel].forEach(textStackView.addArrangedSubview)
        contentView.addSubview(shopPhoto)
        contentView.addSubview(textStackView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            shopPhoto.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Constants.photoInset),
            shopPhoto.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Constants.verticalInset),
            shopPhoto.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Constants.verticalInset),
            shopPhoto.widthAnchor.constraint(equalToConstant: Constants.photoWidth),

            textStackView.leadingAnchor.constraint(equalTo: shopPhoto.trailingAnchor, constant: Constants.textLeading),
            textStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Constants.photoInset),
            textStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Constants.verticalInset),
            textStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Constants.verticalInset)
        ])
    }

    // MARK: - Configuration

    func configure(with item: ShoppingListItem) {
        productNameLabel.text = item.productName
        priceLabel.text = item.priceDescription
        payTypeLabel.text = item.payType
        shopPhoto.image = item.imageData.flatMap(UIImage.init(data:))
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        shopPhoto.image = nil
    }

    // MARK: - Private

}
