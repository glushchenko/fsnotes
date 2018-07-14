//
//  Preferences.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 8/8/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
    import MASShortcut
#else
    import UIKit
    import NightNight
#endif

public class UserDefaultsManagement {
    
#if os(OSX)
    typealias Color = NSColor
    typealias Image = NSImage
    typealias Font = NSFont
#else
    typealias Color = UIColor
    typealias Image = UIImage
    typealias Font = UIFont
#endif
    
    static var DefaultFont = ".AppleSystemUIFont"
    static var DefaultFontSize = 14
    
    static var DefaultFontColor = Color.black
    static var DefaultBgColor = Color.white

    private struct Constants {
        static let ArchiveDirectoryKey = "archiveDirectory"
        static let BgColorKey = "bgColorKeyed"
        static let CellSpacing = "cellSpacing"
        static let CellFrameOriginY = "cellFrameOriginY"
        static let codeBlockHighlight = "codeBlockHighlight"
        static let codeTheme = "codeTheme"
        static let DefaultLanguageKey = "defaultLanguage"
        static let FontNameKey = "font"
        static let FontSizeKey = "fontsize"
        static let FontColorKey = "fontColorKeyed"
        static let HideOnDeactivate = "hideOnDeactivate"
        static let HidePreviewKey = "hidePreview"
        static let LastSelectedPath = "lastSelectedPath"
        static let LastProject = "lastProject"
        static let LineSpacingEditorKey = "lineSpacingEditor"
        static let LiveImagesPreview = "liveImagesPreview"
        static let NewNoteKeyCode = "newNoteKeyCode"
        static let NewNoteKeyModifier = "newNoteKeyModifier"
        static let NightModeType = "nightModeType"
        static let NightModeAuto = "nightModeAuto"
        static let NightModeBrightnessLevel = "nightModeBrightnessLevel"
        static let PinListKey = "pinList"
        static let Preview = "preview"
        static let RestoreCursorPosition = "restoreCursorPosition"
        static let SearchNoteKeyCode = "searchNoteKeyCode"
        static let SearchNoteKeyModifier = "searchNoteKeyModifier"
        static let ShowDockIcon = "showDockIcon"
        static let SortBy = "sortBy"
        static let StoragePathKey = "storageUrl"
        static let StorageExtensionKey = "fileExtension"
        static let TableOrientation = "isUseHorizontalMode"
        static let TextMatchAutoSelection = "textMatchAutoSelection"
        static let AutocloseBrackets = "autocloseBrackets"
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
    
    static var noteFont: Font! {
        get {
            if let font = Font(name: self.fontName, size: CGFloat(self.fontSize)) {
                return font
            }
            
            return Font.systemFont(ofSize: CGFloat(self.fontSize))
        }
        set {
            guard let newValue = newValue else {return}
            
            self.fontName = newValue.fontName
            self.fontSize = Int(newValue.pointSize)
        }
    }
    
    static var fontColor: Color {
        get {
            if let returnFontColor = UserDefaults.standard.object(forKey: Constants.FontColorKey), let color = NSKeyedUnarchiver.unarchiveObject(with: returnFontColor as! Data) as? Color {
                return color
            } else {
                return self.DefaultFontColor
            }
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            UserDefaults.standard.set(data, forKey: Constants.FontColorKey)
        }
    }

    static var bgColor: Color {
        get {
            if let returnBgColor = UserDefaults.standard.object(forKey: Constants.BgColorKey), let color = NSKeyedUnarchiver.unarchiveObject(with: returnBgColor as! Data) as? Color {
                return color
            } else {
                return self.DefaultBgColor
            }
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
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
    
    static var documentDirectory: URL? {
        get {
            if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
                
                if (!FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil)) {
                    do {
                        try FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
                        
                        return iCloudDocumentsURL
                    } catch {
                        print("Home directory creation: \(error)")
                    }
                } else {
                   return iCloudDocumentsURL
                }
            }
            
            if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                return URL(fileURLWithPath: path)
            }
    
            return nil
        }
    }
    
    static var storagePath: String? {
        get {
            if let storagePath = UserDefaults.standard.object(forKey: Constants.StoragePathKey) {
                
                do {
                    try FileManager.default.contentsOfDirectory(atPath: storagePath as! String)
                    
                    return storagePath as? String
                } catch {
                    print(error)
                }
            }
            
            if let dd = documentDirectory {
                return dd.path
            }
            
            return nil
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.StoragePathKey)
        }
    }
    
    static var storageUrl: URL? {
        get {
            if let path = storagePath {
                let expanded = NSString(string: path).expandingTildeInPath

                return URL.init(fileURLWithPath: expanded)
            }
            
            return nil
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
    
#if os(OSX)
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
#endif
        
    static var preview: Bool {
        get {
            if let preview = UserDefaults.standard.object(forKey: Constants.Preview) {
                return preview as! Bool
            } else {
                return false
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
    
    static var sidebarSize: CGFloat {
        get {
            if let size = UserDefaults.standard.object(forKey: "sidebarSize"), let width = size as? CGFloat {
                return width
            }
            
            #if os(iOS)
                return 0
            #else
                return 250
            #endif
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sidebarSize")
        }
    }
    
    static var hideRealSidebar: Bool {
        get {
            if let hide = UserDefaults.standard.object(forKey: "hideRealSidebar") {
                return hide as! Bool
            }
            return false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hideRealSidebar")
        }
    }
    
    static var realSidebarSize: Int {
        get {
            if let size = UserDefaults.standard.object(forKey: "realSidebarSize") {
                return size as! Int
            }
            return 100
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "realSidebarSize")
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
            
            #if os(OSX)
                return "atom-one-light"
            #else
                if NightNight.theme == .night {
                    return "monokai-sublime"
                } else {
                    return "atom-one-light"
                }
            #endif
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.codeTheme)
        }
    }
    
    static var lastSelectedURL: URL? {
        get {
            if let path = UserDefaults.standard.object(forKey: Constants.LastSelectedPath) as? String, let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                return URL(string: "file://" + encodedPath)
            }
            return nil
        }
        set {
            if let url = newValue {
                UserDefaults.standard.set(url.path, forKey: Constants.LastSelectedPath)
            }
        }
    }
    
    static var liveImagesPreview: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.LiveImagesPreview) {
                return result as! Bool
            }
            return true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.LiveImagesPreview)
        }
    }
    
    static var focusInEditorOnNoteSelect: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: "focusInEditorOnNoteSelect") {
                return result as! Bool
            }
            return false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "focusInEditorOnNoteSelect")
        }
    }
    
    static var defaultLanguage: Int {
        get {
            if let dl = UserDefaults.standard.object(forKey: Constants.DefaultLanguageKey) as? Int {
                return dl
            }
            
            return 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.DefaultLanguageKey)
        }
    }
    
    static var restoreCursorPosition: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.RestoreCursorPosition) {
                return result as! Bool
            }
            return true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.RestoreCursorPosition)
        }
    }
    
    static var nightModeAuto: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.NightModeAuto) {
                return result as! Bool
            }
            return false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.NightModeAuto)
        }
    }
    
    #if os(iOS)
        static var nightModeType: NightMode {
            get {
                if let result = UserDefaults.standard.object(forKey: Constants.NightModeType) {
                    return NightMode(rawValue: result as! Int) ?? .disabled
                }
                return NightMode(rawValue: 0x00) ?? .disabled
            }
            set {
                UserDefaults.standard.set(newValue.rawValue, forKey: Constants.NightModeType)
            }
        }
    #endif
    
    static var maxNightModeBrightnessLevel: Float {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.NightModeBrightnessLevel) {
                return result as! Float
            }
            return 35
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.NightModeBrightnessLevel)
        }
    }
    
    static var autocloseBrackets: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.AutocloseBrackets) {
                return result as! Bool
            }
            return false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.AutocloseBrackets)
        }
    }
    
    static var lastProject: Int {
        get {
            if let lastProject = UserDefaults.standard.object(forKey: Constants.LastProject) {
                return lastProject as! Int
            } else {
                return 0
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.LastProject)
        }
    }
    
    static var showDockIcon: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.ShowDockIcon) {
                return result as! Bool
            }
            return true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.ShowDockIcon)
        }
    }
    
    static var archiveDirectory: URL? {
        get {
            if
                let path = UserDefaults.standard.object(forKey: Constants.ArchiveDirectoryKey) as? String,
                let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                
                return URL(string: "file://" + encodedPath + "/")
            }
            
            if let archive = storageUrl?.appendingPathComponent("Archive") {
                if !FileManager.default.fileExists(atPath: archive.path) {
                    do {
                        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: false, attributes: nil)
                        
                        return archive
                    } catch {
                        print(error)
                    }
                } else {
                    return archive
                }
            }
            
            return nil
        }
        
        set {
            if let url = newValue {
                UserDefaults.standard.set(url.path, forKey: Constants.ArchiveDirectoryKey)
            }
        }
    }
    
    static var editorLineSpacing: Float {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.LineSpacingEditorKey) {
                return result as! Float
            }
            return 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.LineSpacingEditorKey)
        }
    }
    
    static var textMatchAutoSelection: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.TextMatchAutoSelection) {
                return result as! Bool
            }
            return true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.TextMatchAutoSelection)
        }
    }
}
