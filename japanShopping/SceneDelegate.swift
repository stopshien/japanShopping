//
//  SceneDelegate.swift
//  japanShopping
//
//  Created by 沈庭鋒 on 2023/5/21.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var factory: ScreenFactory?
    /// 首頁的 navigation controller。啟動動畫與引導流程期間為 nil，不提示方案到期。
    private var mainNavigationController: UINavigationController?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // 所有畫面都已改為程式碼建立，Main.storyboard 已移除。
        // AppScreenFactory 是整個 App 的組裝根，各畫面只透過 ScreenFactory 取得下一個畫面。
        let factory = AppScreenFactory()
        self.factory = factory

        let window = UIWindow(windowScene: windowScene)
        window.tintColor = AppColor.accent
        // 色票是寫死的淺色系（橄欖綠底、白色卡片），沒有對應的深色版本。
        // 不鎖住外觀的話，系統提供的顏色（提示文字、停用狀態）會單獨變深色而糊掉。
        window.overrideUserInterfaceStyle = .light
        window.makeKeyAndVisible()
        self.window = window

        let initialRoot = factory.needsOnboarding
            ? factory.makeOnboarding { [weak self] in self?.showMain() }
            : makeMain(factory: factory)
        let initialMain = initialRoot as? UINavigationController
        let startsAtMain = !factory.needsOnboarding

        // 首頁在啟動動畫播放時就先載入，匯率下載等初始化不必等動畫結束。
        initialRoot.loadViewIfNeeded()
        (initialRoot as? UINavigationController)?.topViewController?.loadViewIfNeeded()

        window.rootViewController = SplashViewController { [weak self] in
            self?.setRoot(initialRoot) {
                // 冷啟動時等動畫播完、首頁出現後才檢查，提示不會蓋在動畫上。
                guard startsAtMain else { return }
                self?.mainNavigationController = initialMain
                self?.remindExpiredPlans()
            }
        }
    }

    /// 有剛到期的回饋方案時提示一次。冷啟動與每次回到前景都會檢查：
    /// iOS 常讓 App 在背景停留好幾天，只看冷啟動的話，整趟旅程可能都不會提示。
    private func remindExpiredPlans() {
        guard let factory, let navigationController = mainNavigationController,
              window?.rootViewController === navigationController else { return }
        // 畫面上已經有彈窗或其他呈現中的畫面時不打斷，下次回到前景再檢查。
        guard let top = navigationController.visibleViewController,
              top.presentedViewController == nil, !(top is UIAlertController) else { return }
        guard let alert = factory.makePlanExpiryAlert(onRenew: { [weak navigationController] controller in
            navigationController?.pushViewController(controller, animated: true)
        }) else { return }
        top.present(alert, animated: true)
    }

    /// 引導流程完成後換掉 root，引導頁隨之釋放，返回手勢也不會回到它。
    private func showMain() {
        guard let factory else { return }
        let main = makeMain(factory: factory)
        setRoot(main) { [weak self] in
            self?.mainNavigationController = main
        }
    }

    private func makeMain(factory: ScreenFactory) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: factory.makeCompute())
        AppAppearance.apply(to: navigationController.navigationBar)
        return navigationController
    }

    private func setRoot(_ viewController: UIViewController, completion: (() -> Void)? = nil) {
        guard let window else { return }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            window.rootViewController = viewController
        }, completion: { _ in
            completion?()
        })
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // 冷啟動時首頁還沒出現，mainNavigationController 是 nil，這裡不會提示；
        // 動畫結束後由 scene(_:willConnectTo:) 補一次。
        remindExpiredPlans()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

