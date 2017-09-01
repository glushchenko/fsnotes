//
//  Preferences.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/8/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation
import Cocoa
import MASShortcut

public class UserDefaultsManagement {
    static var DefaultFont = "Source Code Pro"
    static var DefaultFontSize = 13

    private struct Constants {
        static let FontNameKey = "font"
        static let FontSizeKey = "fontsize"
        static let TableOrientation = "isUseHorizontalMode"
        static let StoragePathKey = "storageUrl"
        static let StorageExtensionKey = "fileExtension"
        static let HidePreviewKey = "hidePreview"
        static let NewNoteKeyCode = "newNoteKeyCode"
        static let NewNoteKeyModifier = "newNoteKeyModifier"
        static let SearchNoteKeyCode = "searchNoteKeyCode"
        static let SearchNoteKeyModifier = "searchNoteKeyModifier"
        static let PinListKey = "pinList"
    }
        
    static var fontName: String {
        get {
            if let returnFontName = UserDefaults.standard.object(forKey: Constants.FontNameKey) {
                return returnFontName as! String
            } else {
                return self.DefaultFont
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.FontNameKey)
        }
    }
    
    static var fontSize: Int {
        get {
            if let returnFontSize = UserDefaults.standard.object(forKey: Constants.FontSizeKey) {
                return returnFontSize as! Int
            } else {
                return self.DefaultFontSize
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.FontSizeKey)
        }
    }
    
    static var noteFont: NSFont! {
        get {
            return NSFont(name: self.fontName, size: CGFloat(self.fontSize))
        }
        set {
            guard let newValue = newValue else {return}
            
            self.fontName = newValue.fontName
            self.fontSize = Int(newValue.pointSize)
        }
    }
    
    static var externalEditor: String {
        get {
            let name = UserDefaults.standard.object(forKey: "externalEditorApp")
            if name != nil && (name as! String).characters.count > 0 {
                return name as! String
            } else {
                return "TextEdit"
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "externalEditorApp")
        }
    }

    static var horizontalOrientation: Bool {
        get {
            if let returnMode = UserDefaults.standard.object(forKey: Constants.TableOrientation) {
                return returnMode as! Bool
            } else {
                return false
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.TableOrientation)
        }
    }
    
    static var storagePath: String {
        get {
            if let storagePath = UserDefaults.standard.object(forKey: Constants.StoragePathKey) {
                return storagePath as! String
            } else {
                return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.StoragePathKey)
        }
    }
    
    static var storageUrl: URL {
        get {
            let expanded = NSString(string: self.storagePath).expandingTildeInPath

            return URL.init(fileURLWithPath: expanded)
        }
    }
    
    static var storageExtension: String {
        get {
            if let storageExtension = UserDefaults.standard.object(forKey: Constants.StorageExtensionKey) {
                return storageExtension as! String
            } else {
                return "md"
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.StorageExtensionKey)
        }
    }
    
    static var hidePreview: Bool {
        get {
            if let returnMode = UserDefaults.standard.object(forKey: Constants.HidePreviewKey) {
                return returnMode as! Bool
            } else {
                return false
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.HidePreviewKey)
        }
    }
    
    static var newNoteShortcut: MASShortcut {
        get {
            let code = UserDefaults.standard.object(forKey: Constants.NewNoteKeyCode)
            let modifier = UserDefaults.standard.object(forKey: Constants.NewNoteKeyModifier)
            
            if (code != nil && modifier != nil) {
                return MASShortcut(keyCode: code as! UInt, modifierFlags: modifier as! UInt)
            } else {
                return MASShortcut(keyCode: 45, modifierFlags: 917504)
            }
        }
        set {
            UserDefaults.standard.set(newValue.keyCode, forKey: Constants.NewNoteKeyCode)
            UserDefaults.standard.set(newValue.modifierFlags, forKey: Constants.NewNoteKeyModifier)
        }
    }
    
    static var searchNoteShortcut: MASShortcut {
        get {
            let code = UserDefaults.standard.object(forKey: Constants.SearchNoteKeyCode)
            let modifier = UserDefaults.standard.object(forKey: Constants.SearchNoteKeyModifier)
            
            if (code != nil && modifier != nil) {
                return MASShortcut(keyCode: code as! UInt, modifierFlags: modifier as! UInt)
            } else {
                return MASShortcut(keyCode: 37, modifierFlags: 917504)
            }
        }
        set {
            UserDefaults.standard.set(newValue.keyCode, forKey: Constants.SearchNoteKeyCode)
            UserDefaults.standard.set(newValue.modifierFlags, forKey: Constants.SearchNoteKeyModifier)
        }
    }
    
    static var pinnedNotes: [String] {
        get {
            if let pinList = UserDefaults.standard.object(forKey: Constants.PinListKey) {
                return pinList as! [String]
            } else {
                return []
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.PinListKey)
        }
    }
    
    static var preview: Bool {
        get {
            if let preview = UserDefaults.standard.object(forKey: "preview") {
                return preview as! Bool
            } else {
                return false
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "preview")
        }
    }
}
