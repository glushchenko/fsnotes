//
//  UIBarButton+.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.11.2025.
//  Copyright © 2025 Oleksandr Hlushchenko. All rights reserved.
//

import UIKit

extension UIBarButtonItem {
    convenience init(systemImageName: String, target: Any, selector: Selector) {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .light, scale: .default)
        let image = UIImage(systemName: systemImageName, withConfiguration: config)?.imageWithColor(color1: UIColor.mainTheme)

        let button = UIButton(type: .system)
        button.setImage(image, for: .normal)
        button.tintColor = .mainTheme
        button.addTarget(target, action: selector, for: .touchUpInside)

        self.init(customView: button)
    }

    convenience init(systemImageName: String, menu: UIMenu) {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .light)
        let image = UIImage(systemName: systemImageName, withConfiguration: config)?
            .imageWithColor(color1: .mainTheme)

        let button = UIButton(type: .system)
        button.setImage(image, for: .normal)
        button.tintColor = .mainTheme
        button.menu = menu
        button.showsMenuAsPrimaryAction = true
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)

        self.init(customView: button)
    }
}
