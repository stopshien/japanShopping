//
//  SplashViewController.swift
//  japanShopping
//

import UIKit

/// App 啟動後播放一次的動畫畫面，播完通知呼叫端換成真正的首頁。
///
/// 沒有 ViewModel：這個畫面沒有狀態也沒有資料，只有一段固定的動畫。
/// 它當 window 的 root，而不是疊在首頁上面，因為首頁與引導頁都在 `viewDidAppear`
/// 叫出鍵盤；疊在上面的話，鍵盤會蓋住動畫。
final class SplashViewController: UIViewController {

    private let onFinish: () -> Void
    private let splashView = SplashView()
    private var hasPlayed = false

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Lifecycle

    override func loadView() {
        view = splashView
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPlayed else { return }
        hasPlayed = true
        splashView.play(reduceMotion: UIAccessibility.isReduceMotionEnabled) { [weak self] in
            self?.onFinish()
        }
    }
}
