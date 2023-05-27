//
//  UIColor+.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 12.05.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import UIKit

extension UIColor {
    public static let mainTheme = UIColor(red: 0.08, green: 0.60, blue: 0.85, alpha: 1.00)

    public static var previewColor: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 0.85, green: 0.87, blue: 0.90, alpha: 1.00) :
                UIColor(red: 0.50, green: 0.56, blue: 0.65, alpha: 1.00)
        }
    }

    public static var sidebar: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1.00) :
                UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.00)
        }
    }

    public static var currentSidebarCell: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 0.41, green: 0.39, blue: 0.45, alpha: 1.00) :
                UIColor(red: 0.81, green: 0.87, blue: 0.95, alpha: 1.00)
        }
    }

    public static var codeBackground: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 0.27, green: 0.27, blue: 0.27, alpha: 1.00) :
                UIColor(red: 0.94, green: 0.95, blue: 0.95, alpha: 1.00)
        }
    }

    public static var whiteBlack: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1.00) :
                UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.00)
        }
    }

    // Black for normal, white for dark
    public static var blackWhite: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.00) :
                UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1.00)
        }
    }

    public static var toolbarTint: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 0.49, green: 0.92, blue: 0.63, alpha: 1.00) :
                UIColor(red: 0.30, green: 0.55, blue: 0.90, alpha: 1.00)
        }
    }

    public static var toolbarBorder: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.00) :
                UIColor(red: 0.84, green: 0.84, blue: 0.87, alpha: 1.00)
        }
    }

    public static var dropDownColor: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1.00) :
                UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.00)
        }
    }

    public static var wikiColor: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 0.00, green: 0.45, blue: 0.15, alpha: 1.00) :
                UIColor(red: 0.29, green: 0.35, blue: 0.60, alpha: 1.00)
        }
    }

    public static var highlightColor: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 0.20, green: 0.55, blue: 0.07, alpha: 1.00) :
                UIColor(red: 1.00, green: 0.90, blue: 0.70, alpha: 1.00)
        }
    }

    public static var linksColor: UIColor {
        return UIColor { (traits) -> UIColor in
            return traits.userInterfaceStyle == .dark ?
                UIColor(red: 0.08, green: 0.60, blue: 0.85, alpha: 1.00) :
                UIColor(red: 0.08, green: 0.60, blue: 0.85, alpha: 1.00)
        }
    }
}
