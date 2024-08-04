//
//  UserDefaultsManagement+.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 10/26/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import UIKit

extension UserDefaultsManagement {
    private struct Constants {
        static let appIcon = "appIcon"
        static let codeTheme = "codeTheme"
        static let currentNote = "currentNote"
        static let currentLocation = "currentLocation"
        static let currentLength = "currentLength"
        static let dynamicTypeFont = "dynamicTypeFont"
        static let editorAutocorrection = "editorAutocorrection"
        static let editorState = "editorState"
        static let editorSuggestions = "editorSuggestions"
        static let IsFirstLaunch = "isFirstLaunch"
        static let ImportURLsKey = "ImportURLs"
    }

    static var appIcon: Int {
        get {
            if let theme = shared?.integer(forKey: Constants.appIcon) {
                return theme
            }

            return 1
        }
        set {
            shared?.set(newValue, forKey: Constants.appIcon)
        }
    }

    static var codeTheme: String {
        get {
            if let theme = shared?.object(forKey: Constants.codeTheme) as? String {
                return theme
            }

            if UITraitCollection.current.userInterfaceStyle == .dark {
                return "monokai-sublime"
            }

            return "github"
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
            return true
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
            return true
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

    static var noteFont: UIFont {
        get {
            if #available(iOS 11.0, *), UserDefaultsManagement.dynamicTypeFont {
                var font = UIFont.systemFont(ofSize: CGFloat(DefaultFontSize))

                if let fontName = UserDefaultsManagement.fontName,
                    let currentFont = UIFont(name: fontName, size: CGFloat(DefaultFontSize)) {
                    font = currentFont
                }

                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                return fontMetrics.scaledFont(for: font)
            }

            if let name = self.fontName, name.starts(with: ".") {
                return UIFont.systemFont(ofSize: CGFloat(self.fontSize))
            }

            if let fontName = self.fontName, let font = UIFont(name: fontName, size: CGFloat(self.fontSize)) {
                return font
            }

            return UIFont.systemFont(ofSize: CGFloat(self.fontSize))
        }
        set {
            self.fontName = newValue.fontName
            self.fontSize = Int(newValue.pointSize)
        }
    }

    static var codeFont: UIFont {
        get {
            if #available(iOS 11.0, *), UserDefaultsManagement.dynamicTypeFont {
                var font = Font.systemFont(ofSize: CGFloat(self.codeFontSize))

                if let currentFont = Font(name: self.codeFontName, size: CGFloat(self.codeFontSize)) {
                    font = currentFont
                }

                let fontMetrics = UIFontMetrics(forTextStyle: .body)
                return fontMetrics.scaledFont(for: font)
            }

            if let font = UIFont(name: self.codeFontName, size: CGFloat(self.codeFontSize)) {
                return font
            }

            return UIFont.systemFont(ofSize: CGFloat(self.codeFontSize))
        }
        set {
            self.codeFontName = newValue.familyName
            self.codeFontSize = Int(newValue.pointSize)
        }
    }

    @available(iOS 11.0, *)
    static var importURLs: [URL] {
        get {
            guard let defaults = UserDefaults.init(suiteName: "group.es.fsnot.user.defaults") else { return [] }

            if let result = defaults.object(forKey: Constants.ImportURLsKey) as? Data,
                let urls = NSArray.unsecureUnarchived(from: result) as? [URL] {
                return urls
            }

            return []
        }
        set {
            guard let defaults = UserDefaults.init(suiteName: "group.es.fsnot.user.defaults") else { return }

            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                defaults.set(data, forKey: Constants.ImportURLsKey)
            }
        }
    }

    static var fontColor: Color {
        get {
            return self.DefaultFontColor
        }
    }

    static var bgColor: Color {
        get {
            return self.DefaultBgColor
        }
    }
}

extension NSCoding where Self: NSObject {
    @available(iOS 11.0, *)
    static func unsecureUnarchived(from data: Data) -> Self? {
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = true
            let obj = unarchiver.decodeObject(of: self, forKey: NSKeyedArchiveRootObjectKey)
            if let error = unarchiver.error {
                print("Error:\(error)")
            }
            return obj
        } catch {
            print("Error:\(error)")
        }
        return nil
    }
}
