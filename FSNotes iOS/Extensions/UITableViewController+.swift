//
//  UITableViewController+.swift
//  FSNotes iOS
//
//  Created by Александр on 24.10.2021.
//  Copyright © 2021 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit
import NightNight

extension UITableViewController {
    @objc func updateNavigationBarBackground() {
        if #available(iOS 13.0, *) {
            var color = UIColor(red: 0.15, green: 0.28, blue: 0.42, alpha: 1.00)

            if NightNight.theme == .night {
                color = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.00)
            }

            guard let navController = navigationController else { return }

            navController.navigationBar.standardAppearance.backgroundColor = color
            navController.navigationBar.standardAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
            navController.navigationBar.scrollEdgeAppearance = navController.navigationBar.standardAppearance
        }
    }
}
