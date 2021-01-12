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
        static let currentController = "currentController"
        static let currentNote = "currentNote"
        static let currentLocation = "currentLocation"
        static let currentLength = "currentLength"
        static let dynamicTypeFont = "dynamicTypeFont"
        static let editorAutocorrection = "editorAutocorrection"
        static let editorState = "editorState"
        static let editorSuggestions = "editorSuggestions"
        static let IsFirstLaunch = "isFirstLaunch"
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

    static var isFirstLaunch: Bool {
        get {
            if let result = shared?.object(forKey: Constants.IsFirstLaunch) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.IsFirstLaunch)
        }
    }

    static var editorAutocorrection: Bool {
        get {
            if let result = shared?.object(forKey: Constants.editorAutocorrection) as? Bool {
                return result
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.editorAutocorrection)
        }
    }

    static var editorSpellChecking: Bool {
        get {
            if let result = shared?.object(forKey: Constants.editorSuggestions) as? Bool {
                return result
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.editorSuggestions)
        }
    }

    static var currentNote: URL? {
        get {
            if let url = shared?.url(forKey: Constants.currentNote) {
                return url
            }
            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.currentNote)
        }
    }

    static var currentController: Int? {
        get {
            if let controller = shared?.integer(forKey: Constants.currentController) {
                return controller
            }
            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.currentController)
        }
    }

    static var currentRange: NSRange? {
        get {
            if let location = shared?.integer(forKey: Constants.currentLocation),
               let length = shared?.integer(forKey: Constants.currentLength) {
                return NSRange(location: location, length: length)
            }
            return nil
        }
        set {
            if let range = newValue {
                shared?.set(range.location, forKey: Constants.currentLocation)
                shared?.set(range.length, forKey: Constants.currentLength)
            } else {
                shared?.set(nil, forKey: Constants.currentLocation)
                shared?.set(nil, forKey: Constants.currentLength)
            }
        }
    }

    static var currentEditorState: Bool? {
        get {
            if let result = shared?.object(forKey: Constants.editorState) as? Bool {
                return result
            }
            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.editorState)
        }
    }
}
