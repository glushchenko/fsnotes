//
//  UserDefaultsManagement+.swift
//  FSNotesCore macOS
//
//  Created by Oleksandr Glushchenko on 10/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import MASShortcut
import AppKit

extension UserDefaultsManagement {
    private struct Constants {
        static let AppearanceTypeKey = "appearanceType2025"
        static let boldKey = "boldKeyed"
        static let codeTheme = "codeTheme"
        static let codeThemeDark = "codeThemeDark"
        static let darkMode = "darkMode"
        static let dockIcon = "dockIcon"
        static let italicKey = "italicKeyed"
        static let NewNoteKeyModifier = "newNoteKeyModifier"
        static let NewNoteKeyCode = "newNoteKeyCode"
        static let SearchNoteKeyCode = "searchNoteKeyCode"
        static let SearchNoteKeyModifier = "searchNoteKeyModifier"
        static let ProjectsKey = "projects"
        static let FontColorKey = "fontColorKeyed"
        static let BgColorKey = "bgColorKeyed"
        static let QuickNoteKey = "quickNoteKey"
        static let QuickNoteKeyModifier = "quickNoteKeyModifier"
    }

    static var appearanceType: AppearanceType {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.AppearanceTypeKey) as? Int {
                return AppearanceType(rawValue: result)!
            }

            return AppearanceType.System
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.AppearanceTypeKey)
        }
    }

    static var newNoteShortcut: MASShortcut? {
        get {
            let code = UserDefaults.standard.object(forKey: Constants.NewNoteKeyCode)
            let modifier = UserDefaults.standard.object(forKey: Constants.NewNoteKeyModifier)

            if code != nil && modifier != nil, let keyCode = code as? UInt, let modifierFlags = modifier as? UInt {

                if (code as? Int) == 0 && (modifier as? Int) == 0 {
                    return nil
                }

                return MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
            }

            return MASShortcut(keyCode: 45, modifierFlags: 917504)
        }
        set {
            let code = newValue?.keyCode ?? 0
            let modifier = newValue?.modifierFlags ?? 0

            UserDefaults.standard.set(code, forKey: Constants.NewNoteKeyCode)
            UserDefaults.standard.set(modifier, forKey: Constants.NewNoteKeyModifier)
        }
    }

    static var quickNoteShortcut: MASShortcut? {
        get {
            let code = UserDefaults.standard.object(forKey: Constants.QuickNoteKey)
            let modifier = UserDefaults.standard.object(forKey: Constants.QuickNoteKeyModifier)

            if code != nil && modifier != nil, let keyCode = code as? UInt, let modifierFlags = modifier as? UInt {

                if (code as? Int) == 0 && (modifier as? Int) == 0 {
                    return nil
                }

                return MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
            }

            return MASShortcut(keyCode: 31, modifierFlags: 917504)
        }
        set {
            let code = newValue?.keyCode ?? 0
            let modifier = newValue?.modifierFlags ?? 0

            UserDefaults.standard.set(code, forKey: Constants.QuickNoteKey)
            UserDefaults.standard.set(modifier, forKey: Constants.QuickNoteKeyModifier)
        }
    }

    static var searchNoteShortcut: MASShortcut? {
        get {
            let code = UserDefaults.standard.object(forKey: Constants.SearchNoteKeyCode)
            let modifier = UserDefaults.standard.object(forKey: Constants.SearchNoteKeyModifier)

            if code != nil && modifier != nil, let keyCode = code as? UInt, let modifierFlags = modifier as? UInt {

                if (code as? Int) == 0 && (modifier as? Int) == 0 {
                    return nil
                }

                return MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
            }

            return MASShortcut(keyCode: 37, modifierFlags: 917504)
        }
        set {
            let code = newValue?.keyCode ?? 0
            let modifier = newValue?.modifierFlags ?? 0

            UserDefaults.standard.set(code, forKey: Constants.SearchNoteKeyCode)
            UserDefaults.standard.set(modifier, forKey: Constants.SearchNoteKeyModifier)
        }
    }

    static var dockIcon: Int {
        get {
            if let tag = UserDefaults.standard.object(forKey: Constants.dockIcon) as? Int {
                return tag
            }

            return 0
        }

        set {
            UserDefaults.standard.set(newValue, forKey: Constants.dockIcon)
        }
    }

    static var noteFont: NSFont {
        get {
            if let name = fontName, name.starts(with: ".") {
                return NSFont.systemFont(ofSize: CGFloat(self.fontSize))
            }

            if let fontName = self.fontName, let font = NSFont(name: fontName, size: CGFloat(self.fontSize)) {
                return font
            }

            return NSFont.systemFont(ofSize: CGFloat(self.fontSize))
        }
        set {
            self.fontName = newValue.fontName
            self.fontSize = Int(newValue.pointSize)
        }
    }

    static var codeFont: NSFont {
        get {
            if let font = NSFont(name: self.codeFontName, size: CGFloat(self.codeFontSize)) {
                return font
            }

            return NSFont.systemFont(ofSize: CGFloat(self.codeFontSize))
        }
        set {
            self.codeFontName = newValue.familyName ?? "Source Code Pro"
            self.codeFontSize = Int(newValue.pointSize)
        }
    }

    static var fontColor: Color {
        get {
            return self.DefaultFontColor
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                shared?.set(data, forKey: Constants.FontColorKey)
            }
        }
    }

    static var bgColor: Color {
        get {
            return self.DefaultBgColor
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                shared?.set(data, forKey: Constants.BgColorKey)
            }
        }
    }
    
    static var italic: String {
        get {
            if let returnFontName = shared?.object(forKey: Constants.italicKey) as? String {
                return returnFontName
            }
            
            return "*"
        }
        set {
            shared?.set(newValue, forKey: Constants.italicKey)
        }
    }
    
    static var bold: String {
        get {
            if let returnFontName = shared?.object(forKey: Constants.boldKey) as? String {
                return returnFontName
            }
            
            return "__"
        }
        set {
            shared?.set(newValue, forKey: Constants.boldKey)
        }
    }
}
