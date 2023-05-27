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

        DispatchQueue.main.async {
            UIApplication.getVC().loadPlusButton()
        }

        return super.popViewController(animated: animated)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let evc = UIApplication.getEVC()
            evc.topBorder.backgroundColor = UIColor.toolbarBorder.cgColor

            MPreviewView.template = nil
            NotesTextProcessor.hl = nil

            evc.refill()
        }
    }
}
