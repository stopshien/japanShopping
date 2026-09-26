//
//  ShoppingListCell.swift
//  japanShopping
//
//  取代原本 storyboard 上的 ListTableViewCell。
//

import UIKit

/// 消費紀錄的一列：左邊商品與付款方式，右邊金額。
///
/// 金額靠右對齊，由上往下掃就能比較每一筆花了多少；商品名稱不再用大字，
/// 否則會和金額互相搶注意力，列也會高到一頁看不到幾筆。
final class ShoppingListCell: UITableViewCell {

    static let reuseIdentifier = "ShoppingListCell"

    private enum Constants {
        static let photoWidth: CGFloat = 56
        static let photoInset: CGFloat = AppStyle.Spacing.normal
        static let verticalInset: CGFloat = AppStyle.Spacing.tight + 4
        static let textLeading: CGFloat = 12
        static let tagHorizontalInset: CGFloat = 8
        static let tagVerticalInset: CGFloat = 2
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

    private let productNameLabel = AppView.label(font: AppStyle.Font.bodyEmphasis)
    private let amountLabel = AppView.label(font: AppStyle.Font.amountRow, alignment: .right)

    /// 付款方式放進淡色標籤，和稅別分開，掃視時看得出是哪張卡。
    private let payTypeLabel = AppView.label(font: AppStyle.Font.caption, color: AppColor.accent)
    private let payTypeTag = UIView()
    private let taxStateLabel = AppView.label(font: AppStyle.Font.caption, color: AppColor.textSecondary)

    private lazy var detailRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [payTypeTag, taxStateLabel, UIView()])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = AppStyle.Spacing.tight
        return row
    }()

    private lazy var textStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [productNameLabel, detailRow])
        stackView.axis = .vertical
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
        backgroundColor = AppColor.surface

        payTypeTag.backgroundColor = AppColor.accentSoft
        payTypeTag.layer.cornerRadius = AppStyle.Radius.control / 2
        payTypeTag.translatesAutoresizingMaskIntoConstraints = false
        payTypeTag.addSubview(payTypeLabel)

        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentView.addSubview(shopPhoto)
        contentView.addSubview(textStackView)
        contentView.addSubview(amountLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            shopPhoto.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Constants.photoInset),
            shopPhoto.topAnchor.constraint(
                greaterThanOrEqualTo: contentView.topAnchor, constant: Constants.verticalInset
            ),
            shopPhoto.bottomAnchor.constraint(
                lessThanOrEqualTo: contentView.bottomAnchor, constant: -Constants.verticalInset
            ),
            shopPhoto.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            photoWidthConstraint,
            // 照片維持正方形，列高由文字決定。
            shopPhoto.heightAnchor.constraint(equalTo: shopPhoto.widthAnchor),

            payTypeLabel.topAnchor.constraint(equalTo: payTypeTag.topAnchor, constant: Constants.tagVerticalInset),
            payTypeLabel.bottomAnchor.constraint(
                equalTo: payTypeTag.bottomAnchor, constant: -Constants.tagVerticalInset
            ),
            payTypeLabel.leadingAnchor.constraint(
                equalTo: payTypeTag.leadingAnchor, constant: Constants.tagHorizontalInset
            ),
            payTypeLabel.trailingAnchor.constraint(
                equalTo: payTypeTag.trailingAnchor, constant: -Constants.tagHorizontalInset
            ),

            textStackView.leadingAnchor.constraint(equalTo: shopPhoto.trailingAnchor, constant: Constants.textLeading),
            textStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Constants.verticalInset),
            textStackView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -Constants.verticalInset
            ),

            amountLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: textStackView.trailingAnchor, constant: AppStyle.Spacing.tight
            ),
            // 右側是「>」箭頭，金額不要貼著它。
            amountLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -AppStyle.Spacing.tight
            ),
            amountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    // MARK: - Configuration

    func configure(with item: ShoppingListItem) {
        productNameLabel.text = item.productName
        amountLabel.text = item.amount
        payTypeLabel.text = item.payType
        payTypeTag.isHidden = item.payType.isEmpty
        taxStateLabel.text = item.taxState

        // 沒有照片就不留空位，讓文字靠左。
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
}
