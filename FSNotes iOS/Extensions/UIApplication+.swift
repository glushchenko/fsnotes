//
//  UIApplication.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/21/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

extension UIApplication {

    // MARK: - Scene Delegate Access

    static func getSceneDelegate() -> SceneDelegate? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sceneDelegate = windowScene.delegate as? SceneDelegate else {
            return nil
        }
        return sceneDelegate
    }

    // MARK: - View Controllers Access

    static func getVC() -> ViewController {
        guard let sceneDelegate = getSceneDelegate() else {
            fatalError("SceneDelegate not found")
        }
        return sceneDelegate.listController
    }

    static func getEVC() -> EditorViewController {
        guard let sceneDelegate = getSceneDelegate() else {
            fatalError("SceneDelegate not found")
        }
        return sceneDelegate.editorController
    }

    static func getNC() -> MainNavigationController? {
        guard let sceneDelegate = getSceneDelegate() else {
            return nil
        }
        return sceneDelegate.mainController
    }

    // MARK: - App Delegate Access

    static func getDelegate() -> AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    // MARK: - Window Access (Optional Helper)

    static func getWindow() -> UIWindow? {
        return getSceneDelegate()?.window
    }
}
