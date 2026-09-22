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
    /// 稅別改成金額旁的小標籤，不再用括號夾在金額後面。
    private let taxStateLabel = AppView.label(font: AppStyle.Font.caption, color: AppColor.textSecondary)
    private let payTypeLabel = AppView.label(font: AppStyle.Font.body, color: AppColor.textSecondary)

    private lazy var priceRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [priceLabel, taxStateLabel, UIView()])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = AppStyle.Spacing.tight / 2
        return row
    }()

    private let textStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        // 不用 fillEqually：大字級時每行高度不同，等分會把列撐得很誇張。
        stackView.distribution = .fill
        stackView.spacing = AppStyle.Spacing.tight / 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var photoWidthConstraint =
        shopPhoto.widthAnchor.constraint(equalToConstant: Constants.photoWidth)

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
        [productNameLabel, priceRow, payTypeLabel].forEach(textStackView.addArrangedSubview)
        contentView.addSubview(shopPhoto)
        contentView.addSubview(textStackView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            shopPhoto.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Constants.photoInset),
            photoWidthConstraint,
            shopPhoto.topAnchor.constraint(
                greaterThanOrEqualTo: contentView.topAnchor, constant: Constants.verticalInset
            ),
            shopPhoto.bottomAnchor.constraint(
                lessThanOrEqualTo: contentView.bottomAnchor, constant: -Constants.verticalInset
            ),
            shopPhoto.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            // 照片維持正方形，列高由文字決定。
            shopPhoto.heightAnchor.constraint(equalTo: shopPhoto.widthAnchor),

            textStackView.leadingAnchor.constraint(equalTo: shopPhoto.trailingAnchor, constant: Constants.textLeading),
            textStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Constants.photoInset),
            textStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Constants.verticalInset),
            textStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Constants.verticalInset)
        ])
    }

    // MARK: - Configuration

    func configure(with item: ShoppingListItem) {
        productNameLabel.text = item.productName
        priceLabel.text = item.amount
        taxStateLabel.text = item.taxState
        payTypeLabel.text = item.payType

        // 沒有照片就不留空灰塊，讓文字靠左。
        let image = item.imageData.flatMap(UIImage.init(data:))
        shopPhoto.image = image
        shopPhoto.isHidden = image == nil
        photoWidthConstraint.constant = image == nil ? 0 : Constants.photoWidth
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        shopPhoto.image = nil
        shopPhoto.isHidden = true
        photoWidthConstraint.constant = 0
    }

    // MARK: - Private

}
