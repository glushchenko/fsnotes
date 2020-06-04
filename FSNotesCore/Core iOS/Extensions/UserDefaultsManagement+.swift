//
//  UserDefaultsManagement+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/26/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import NightNight

extension UserDefaultsManagement {
    private struct Constants {
        static let codeTheme = "codeTheme"
        static let dynamicTypeFont = "dynamicTypeFont"
    }

    static var codeTheme: String {
        get {
            if let theme = UserDefaults.standard.object(forKey: Constants.codeTheme) as? String {
                return theme
            }

            if NightNight.theme == .night {
                return "monokai-sublime"
            }

            return "atom-one-light"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.codeTheme)
        }
    }

    static var dynamicTypeFont: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.dynamicTypeFont) as? Bool {
                return result
            }
            return true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.dynamicTypeFont)
        }
    }

    static var previewMode: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: "previewMode") as? Bool {
                return result
            }
            return false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "previewMode")
        }
    }

    static var sidebarIsOpened: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: "sidebarIsOpened") as? Bool {
                return result
            }
            return false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sidebarIsOpened")
        }
    }
}
