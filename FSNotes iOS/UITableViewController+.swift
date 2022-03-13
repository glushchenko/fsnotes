//
//  UITableViewController+.swift
//  FSNotes iOS
//
//  Created by Александр on 26.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit
import NightNight

extension UITableViewController {
    public func initNavigationBackground() {
        navigationController?.navigationBar.mixedTitleTextAttributes = [NNForegroundColorAttributeName: Colors.titleText]
        navigationController?.navigationBar.mixedTintColor = Colors.buttonText
        navigationController?.navigationBar.mixedBarTintColor = Colors.Header
        navigationController?.navigationBar.mixedBackgroundColor = Colors.Header

        updateNavigationBarBackground()

        NotificationCenter.default.addObserver(self, selector: #selector(updateNavigationBarBackground), name: NSNotification.Name(rawValue: NightNightThemeChangeNotification), object: nil)
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

            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
    }
}
