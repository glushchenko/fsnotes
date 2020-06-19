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
            if let theme = shared?.object(forKey: Constants.codeTheme) as? String {
                return theme
            }

            if NightNight.theme == .night {
                return "monokai-sublime"
            }

            return "atom-one-light"
        }
        set {
            shared?.set(newValue, forKey: Constants.codeTheme)
        }
    }

    static var dynamicTypeFont: Bool {
        get {
            if let result = shared?.object(forKey: Constants.dynamicTypeFont) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.dynamicTypeFont)
        }
    }

    static var previewMode: Bool {
        get {
            if let result = shared?.object(forKey: "previewMode") as? Bool {
                return result
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: "previewMode")
        }
    }

    static var sidebarIsOpened: Bool {
        get {
            if let result = shared?.object(forKey: "sidebarIsOpened") as? Bool {
                return result
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: "sidebarIsOpened")
        }
    }

    static var naming: SettingsFilesNaming {
        get {
            if let result = shared?.object(forKey: "naming") as? Int, let settings = SettingsFilesNaming(rawValue: result) {
                return settings
            }

            return .uuid
        }
        set {
            shared?.set(newValue.rawValue, forKey: "naming")
        }
    }
}
