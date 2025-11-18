//
//  MainNavigationController.swift
//  FSNotes iOS
//
//  Created by Александр on 23.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import UIKit

class MainNavigationController: UINavigationController {
    override func popViewController(animated: Bool) -> UIViewController? {
        UserDefaultsManagement.currentNote = nil

        topViewController?.view.endEditing(true)

        return super.popViewController(animated: animated)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let evc = UIApplication.getEVC()
            
            evc.editArea.textStorage.updateCheckboxList()

            if let previewView = evc.getPreviewView() {
                let funcName = self.traitCollection.userInterfaceStyle == .dark ?  "switchToDarkMode" : "switchToLightMode"
                let switchScript = "if (typeof(\(funcName)) == 'function') { \(funcName)(); }"

                previewView.evaluateJavaScript(switchScript)
            }
        }
    }
}
