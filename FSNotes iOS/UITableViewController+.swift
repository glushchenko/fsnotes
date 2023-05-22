//
//  UITableViewController+.swift
//  FSNotes iOS
//
//  Created by Александр on 26.01.2022.
//  Copyright © 2022 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit

extension UITableViewController {
    public func initZeroNavigationBackground() {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 0

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.largeTitleTextAttributes = [NSAttributedString.Key.paragraphStyle : style]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
}
