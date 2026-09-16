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
        static let photoWidth: CGFloat = 164
        static let photoInset: CGFloat = 20
        static let verticalInset: CGFloat = 8
        static let textLeading: CGFloat = 14
        static let nameFontSize: CGFloat = 25
        static let detailFontSize: CGFloat = 20
    }

    private let shopPhoto: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let productNameLabel = ShoppingListCell.makeLabel(fontSize: Constants.nameFontSize)
    private let priceLabel = ShoppingListCell.makeLabel(fontSize: Constants.detailFontSize)
    private let payTypeLabel = ShoppingListCell.makeLabel(fontSize: Constants.detailFontSize)

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

    private static func makeLabel(fontSize: CGFloat) -> UILabel {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: fontSize)
        label.textColor = AppColor.brand
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}
