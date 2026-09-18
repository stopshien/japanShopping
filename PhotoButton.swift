//
//  PhotoButton.swift
//  japanShopping
//

import UIKit

/// 點選後挑選照片的區塊。沒有照片時顯示圖示，有照片時以原色填滿。
///
/// 不能直接對按鈕 `setImage`：system 按鈕會把圖片當成樣板圖，照片會被主題色整片塗滿。
final class PhotoButton: UIButton {

    private let photoView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        imageView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    init(accessibilityLabel: String) {
        super.init(frame: .zero)
        self.accessibilityLabel = accessibilityLabel
        backgroundColor = AppColor.surface
        clipsToBounds = true
        layer.cornerRadius = AppStyle.Radius.card
        setImage(UIImage(systemName: "photo"), for: .normal)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(photoView)
        NSLayoutConstraint.activate([
            photoView.topAnchor.constraint(equalTo: topAnchor),
            photoView.leadingAnchor.constraint(equalTo: leadingAnchor),
            photoView.trailingAnchor.constraint(equalTo: trailingAnchor),
            photoView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setPhoto(_ image: UIImage?) {
        photoView.image = image
        photoView.isHidden = image == nil
        // 圖示藏在照片後面仍會在按下時變色，有照片時直接拿掉。
        setImage(image == nil ? UIImage(systemName: "photo") : nil, for: .normal)
    }
}
