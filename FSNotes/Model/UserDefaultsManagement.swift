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
    static var DefaultFont = "Helvetica"
    static var DefaultFontSize = 13
    static var DefaultFontColor = NSColor.black
    static var DefaultBgColor = NSColor.white

    private struct Constants {
        static let FontNameKey = "font"
        static let FontSizeKey = "fontsize"
        static let FontColorKey = "fontcolor"
        static let BgColorKey = "bgcolor"
        static let TableOrientation = "isUseHorizontalMode"
        static let StoragePathKey = "storageUrl"
        static let StorageExtensionKey = "fileExtension"
        static let NewNoteKeyCode = "newNoteKeyCode"
        static let NewNoteKeyModifier = "newNoteKeyModifier"
        static let SearchNoteKeyCode = "searchNoteKeyCode"
        static let SearchNoteKeyModifier = "searchNoteKeyModifier"
        static let PinListKey = "pinList"
        static let Preview = "preview"
        static let HideOnDeactivate = "hideOnDeactivate"
        static let CellSpacing = "cellSpacing"
        static let CellFrameOriginY = "cellFrameOriginY"
        static let CloudKitSync = "cloudKitSync"
        static let HidePreviewKey = "hidePreview"
        static let SortBy = "sortBy"
        static let codeBlockHighlight = "codeBlockHighlight"
        static let codeTheme = "codeTheme"
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
    
    static var fontColor: NSColor {
        get {
            if let returnFontColor = UserDefaults.standard.object(forKey: Constants.FontColorKey) {
                return NSUnarchiver.unarchiveObject(with: returnFontColor as! Data) as! NSColor
            } else {
                return self.DefaultFontColor
            }
        }
        set {
            let data = NSArchiver.archivedData(withRootObject: newValue)
            UserDefaults.standard.set(data, forKey: Constants.FontColorKey)
        }
    }

    static var bgColor: NSColor {
        get {
            if let returnBgColor = UserDefaults.standard.object(forKey: Constants.BgColorKey) {
                return NSUnarchiver.unarchiveObject(with: returnBgColor as! Data) as! NSColor
            } else {
                return self.DefaultBgColor
            }
        }
        set {
            let data = NSArchiver.archivedData(withRootObject: newValue)
            UserDefaults.standard.set(data, forKey: Constants.BgColorKey)
        }
    }
    
    static var externalEditor: String {
        get {
            let name = UserDefaults.standard.object(forKey: "externalEditorApp")
            if name != nil && (name as! String).count > 0 {
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
            
#if USEDEBUGFOLDER
            var isDirectory: ObjCBool = true
            let debugFolder = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/FSNotes/"

            if FileManager.default.fileExists(atPath: debugFolder, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    return debugFolder
                }
            }
    
            do {
                try FileManager.default.createDirectory(atPath: debugFolder, withIntermediateDirectories: false, attributes: nil)
                return debugFolder
            } catch let error as NSError {
                print(error.localizedDescription);
            }
#endif
            
            let defaultPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            
            if let storagePath = UserDefaults.standard.object(forKey: Constants.StoragePathKey) {
                do {
                    try FileManager.default.contentsOfDirectory(atPath: storagePath as! String)
                    return storagePath as! String
                } catch {
                    UserDefaultsManagement.storagePath = defaultPath
                    print(error.localizedDescription);
                }
            }
            
            return defaultPath
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
        
    static var preview: Bool {
        get {
            if let preview = UserDefaults.standard.object(forKey: Constants.Preview) {
                return preview as! Bool
            } else {
                return true
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.Preview)
        }
    }
    
    static var lastSync: Date? {
        get {
            if let sync = UserDefaults.standard.object(forKey: "lastSync") {
                return sync as? Date
            } else {
                return nil
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastSync")
        }
    }
    
    static var hideOnDeactivate: Bool {
        get {
            if let hideOnDeactivate = UserDefaults.standard.object(forKey: Constants.HideOnDeactivate) {
                return hideOnDeactivate as! Bool
            } else {
                return false
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.HideOnDeactivate)
        }
    }
    
    static var cellSpacing: Int {
        get {
            if let cellSpacing = UserDefaults.standard.object(forKey: Constants.CellSpacing) {
                return (cellSpacing as! NSNumber).intValue
            } else {
                return 33
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.CellSpacing)
        }
    }
        
    static var cellViewFrameOriginY: CGFloat? {        
        get {
            if let value = UserDefaults.standard.object(forKey: Constants.CellFrameOriginY) {
                return value as? CGFloat
            }
            return nil
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.CellFrameOriginY)
        }
    }
    
    static var cloudKitSync: Bool {
        get {
            if let cloudKitSync = UserDefaults.standard.object(forKey: Constants.CloudKitSync) {
                return cloudKitSync as! Bool
            } else {
                return false
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.CloudKitSync)
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
    
    static var fsImportIsAvailable: Bool {
        get {
            if let returnMode = UserDefaults.standard.object(forKey: "fsImportIsAvailable") {
                return returnMode as! Bool
            } else {
                return true
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "fsImportIsAvailable")
        }
    }
    
    static var sort: SortBy {
        get {
            if let result = UserDefaults.standard.object(forKey: "sortBy"), let sortBy = SortBy(rawValue: result as! String) {
                return sortBy
            } else {
                return SortBy(rawValue: SortBy.ModificationDate.rawValue)!
            }
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "sortBy")
        }
    }
    
    static var sortDirection: Bool {
        get {
            if let returnMode = UserDefaults.standard.object(forKey: "sortDirection") {
                return returnMode as! Bool
            } else {
                return true
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sortDirection")
        }
    }
    
    static var hideSidebar: Bool {
        get {
            if let hide = UserDefaults.standard.object(forKey: "hideSidebar") {
                return hide as! Bool
            }
            return false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hideSidebar")
        }
    }
    
    static var sidebarSize: Int {
        get {
            if let size = UserDefaults.standard.object(forKey: "sidebarSize") {
                return size as! Int
            }
            return 250
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sidebarSize")
        }
    }
    
    static var codeBlockHighlight: Bool {
        get {
            if let highlight = UserDefaults.standard.object(forKey: Constants.codeBlockHighlight) {
                return highlight as! Bool
            }
            return true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.codeBlockHighlight)
        }
    }
    
    static var codeTheme: String {
        get {
            if let theme = UserDefaults.standard.object(forKey: Constants.codeTheme) {
                return theme as! String
            }
            return "atom-one-light"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.codeTheme)
        }
    }
    
}
