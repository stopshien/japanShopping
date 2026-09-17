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


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // 所有畫面都已改為程式碼建立，Main.storyboard 已移除。
        // AppScreenFactory 是整個 App 的組裝根，各畫面只透過 ScreenFactory 取得下一個畫面。
        let factory = AppScreenFactory()
        self.factory = factory

        let window = UIWindow(windowScene: windowScene)
        window.tintColor = AppColor.accent
        window.makeKeyAndVisible()
        self.window = window

        if factory.needsWelcome {
            window.rootViewController = factory.makeWelcome { [weak self] in
                self?.showMain(animated: true)
            }
        } else {
            showMain(animated: false)
        }
    }

    /// 歡迎頁完成後換掉 root，歡迎頁隨之釋放，返回手勢也不會回到它。
    private func showMain(animated: Bool) {
        guard let window, let factory else { return }

        let navigationController = UINavigationController(rootViewController: factory.makeCompute())
        ComputeAppearance.apply(to: navigationController.navigationBar)

        guard animated else {
            window.rootViewController = navigationController
            return
        }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = navigationController
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
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

