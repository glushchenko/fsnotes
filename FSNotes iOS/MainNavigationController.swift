//
//  MainNavigationController.swift
//  FSNotes iOS
//
//  Created by Александр on 23.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import UIKit
import NightNight

class MainNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationBar.mixedTintColor = Colors.buttonText
        navigationBar.mixedBarTintColor = Colors.Header
        navigationBar.mixedBackgroundColor = Colors.Header

        updateNavigationBarBackground()

        NotificationCenter.default.addObserver(self, selector: #selector(updateNavigationBarBackground), name: NSNotification.Name(rawValue: NightNightThemeChangeNotification), object: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

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

        guard UserDefaultsManagement.nightModeType == .system else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkDarkMode()
            self.updateNavigationBarBackground()
        }
    }

    public func checkDarkMode() {
        if #available(iOS 12.0, *) {
            if traitCollection.userInterfaceStyle == .dark {
                if NightNight.theme != .night {
                    enableNightMode()
                }
            } else {
                if NightNight.theme == .night {
                    disableNightMode()
                }
            }
        }
    }

    @objc public func updateNavigationBarBackground() {
        if #available(iOS 13.0, *) {
            var color = UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00)
            if NightNight.theme == .night {
                color = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00)
            }

            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = color
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        }
    }

    public func enableNightMode() {
        print("Dark mode enabled")

        NightNight.theme = .night

        let vc = UIApplication.getVC()
        let evc = UIApplication.getEVC()

        MPreviewView.template = nil

        UserDefaultsManagement.codeTheme = "monokai-sublime"
        NotesTextProcessor.hl = nil
        evc.refill()

        if evc.editArea != nil {
            evc.editArea.keyboardAppearance = .dark
            evc.editArea.indicatorStyle = (NightNight.theme == .night) ? .white : .black
        }

        if let textFieldInsideSearchBar = vc.navigationItem.searchController?.searchBar.value(forKey: "searchField") as? UITextField {
            textFieldInsideSearchBar.keyboardAppearance = NightNight.theme == .night ? .dark : .default
        }

        vc.sidebarTableView.backgroundColor = UIColor(red:0.19, green:0.21, blue:0.21, alpha:1.0)
        vc.sidebarTableView.updateColors()

        vc.sidebarTableView.layoutSubviews()
        vc.notesTable.layoutSubviews()
    }

    public func disableNightMode()
    {
        print("Dark mode disabled")

        NightNight.theme = .normal

        let vc = UIApplication.getVC()
        let evc = UIApplication.getEVC()

        MPreviewView.template = nil

        UserDefaultsManagement.codeTheme = "github"
        NotesTextProcessor.hl = nil
        evc.refill()

        if evc.editArea != nil {
            evc.editArea.keyboardAppearance = .default
            evc.editArea.indicatorStyle = (NightNight.theme == .night) ? .white : .black
        }

        if let textFieldInsideSearchBar = vc.navigationItem.searchController?.searchBar.value(forKey: "searchField") as? UITextField {
            textFieldInsideSearchBar.keyboardAppearance = NightNight.theme == .night ? .dark : .default
        }

        vc.sidebarTableView.layoutSubviews()
        vc.notesTable.layoutSubviews()
    }
}
