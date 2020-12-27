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
#else
    import UIKit
#endif

public class UserDefaultsManagement {
    
#if os(OSX)
    typealias Color = NSColor
    typealias Image = NSImage
    typealias Font = NSFont

    public static var shared: UserDefaults? = UserDefaults.standard
    static var DefaultFontSize = 14
#else
    typealias Color = UIColor
    typealias Image = UIImage
    typealias Font = UIFont

    public static var shared: UserDefaults? = UserDefaults(suiteName: "group.es.fsnot.user.defaults")
    static var DefaultFontSize = 17
#endif

    static var DefaultSnapshotsInterval = 1
    static var DefaultSnapshotsIntervalMinutes = 5
    
    static var DefaultFontColor = Color.black
    static var DefaultBgColor = Color.white

    private struct Constants {
        static let AllowTouchID = "allowTouchID"
        static let AppearanceTypeKey = "appearanceType"
        static let ArchiveDirectoryKey = "archiveDirectory"
        static let AutoInsertHeader = "autoInsertHeader"
        static let AutomaticSpellingCorrection = "automaticSpellingCorrection"
        static let AutomaticQuoteSubstitution = "automaticQuoteSubstitution"
        static let AutomaticDataDetection = "automaticDataDetection"
        static let AutomaticLinkDetection = "automaticLinkDetection"
        static let AutomaticTextReplacement = "automaticTextReplacement"
        static let AutomaticDashSubstitution = "automaticDashSubstitution"
        static let BackupManually = "backupManually"
        static let BgColorKey = "bgColorKeyed"
        static let CacheDiff = "cacheDiff"
        static let CellSpacing = "cellSpacing"
        static let CellFrameOriginY = "cellFrameOriginY"
        static let CodeFontNameKey = "codeFont"
        static let CodeFontSizeKey = "codeFontSize"
        static let codeBlockHighlight = "codeBlockHighlight"
        static let codeTheme = "codeTheme"
        static let ContinuousSpellChecking = "continuousSpellChecking"
        static let CrashedLastTime = "crashedLastTime"
        static let DefaultLanguageKey = "defaultLanguage"
        static let FontNameKey = "font"
        static let FontSizeKey = "fontsize"
        static let FontColorKey = "fontColorKeyed"
        static let FullScreen = "fullScreen"
        static let FirstLineAsTitle = "firstLineAsTitle"
        static let NoteType = "noteType"
        static let NoteExtension = "noteExtension"
        static let GrammarChecking = "grammarChecking"
        static let GitStorage = "gitStorage"
        static let HideDate = "hideDate"
        static let HideOnDeactivate = "hideOnDeactivate"
        static let HideSidebar = "hideSidebar"
        static let HidePreviewKey = "hidePreview"
        static let HidePreviewImages = "hidePreviewImages"
        static let ImagesWidthKey = "imagesWidthKey"
        static let ImportURLsKey = "ImportURLs"
        static let IndentedCodeBlockHighlighting = "IndentedCodeBlockHighlighting"
        static let InlineTags = "inlineTags"
        static let LastNews = "lastNews"
        static let LastSelectedPath = "lastSelectedPath"
        static let LastProject = "lastProject"
        static let LineSpacingEditorKey = "lineSpacingEditor"
        static let LineWidthKey = "lineWidth"
        static let LiveImagesPreview = "liveImagesPreview"
        static let LockOnSleep = "lockOnSleep"
        static let LockOnScreenActivated = "lockOnScreenActivated"
        static let LockAfterIDLE = "lockAfterIdle"
        static let LockAfterUserSwitch = "lockAfterUserSwitch"
        static let MarginSizeKey = "marginSize"
        static let MarkdownPreviewCSS = "markdownPreviewCSS"
        static let MasterPasswordHint = "masterPasswordHint"
        static let MathJaxPreview = "mathJaxPreview"
        static let NightModeType = "nightModeType"
        static let NightModeAuto = "nightModeAuto"
        static let NightModeBrightnessLevel = "nightModeBrightnessLevel"
        static let NoteContainer = "noteContainer"
        static let PinListKey = "pinList"
        static let Preview = "preview"
        static let PreviewFontSize = "previewFontSize"
        static let ProjectsKey = "projects"
        static let RestoreCursorPosition = "restoreCursorPosition"
        static let SaveInKeychain = "saveInKeychain"
        static let SharedContainerKey = "sharedContainer"
        static let ShowDockIcon = "showDockIcon"
        static let shouldFocusSearchOnESCKeyDown = "shouldFocusSearchOnESCKeyDown"
        static let ShowInMenuBar = "showInMenuBar"
        static let SmartInsertDelete = "smartInsertDelete"
        static let SnapshotsInterval = "snapshotsInterval"
        static let SnapshotsIntervalMinutes = "snapshotsIntervalMinutes"
        static let SortBy = "sortBy"
        static let StorageType = "storageType"
        static let SpacesInsteadTabs = "spacesInsteadTabs"
        static let StoragePathKey = "storageUrl"
        static let TableOrientation = "isUseHorizontalMode"
        static let TextMatchAutoSelection = "textMatchAutoSelection"
        static let AutocloseBrackets = "autocloseBrackets"
        static let Welcome = "welcome"
    }

    static var codeFontName: String {
        get {
            if let returnFontName = shared?.object(forKey: Constants.CodeFontNameKey) {
                return returnFontName as! String
            } else {
                return "Source Code Pro"
            }
        }
        set {
            shared?.set(newValue, forKey: Constants.CodeFontNameKey)
        }
    }

    static var codeFontSize: Int {
        get {
            if let returnFontSize = shared?.object(forKey: Constants.CodeFontSizeKey) {
                return returnFontSize as! Int
            } else {
                return self.DefaultFontSize
            }
        }
        set {
            shared?.set(newValue, forKey: Constants.CodeFontSizeKey)
        }
    }

    static var fontName: String? {
        get {
            if let returnFontName = shared?.object(forKey: Constants.FontNameKey) as? String {
                return returnFontName
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.FontNameKey)
        }
    }
    
    static var fontSize: Int {
        get {
        #if os(iOS)
            if UserDefaultsManagement.dynamicTypeFont {
                return self.DefaultFontSize
            }
        #endif

            if let returnFontSize = shared?.object(forKey: Constants.FontSizeKey) {
                return returnFontSize as! Int
            } else {
                return self.DefaultFontSize
            }
        }
        set {
            shared?.set(newValue, forKey: Constants.FontSizeKey)
        }
    }

    static var codeFont: Font! {
        get {
            if let font = Font(name: self.codeFontName, size: CGFloat(self.codeFontSize)) {
                return font
            }

            return Font.systemFont(ofSize: CGFloat(self.codeFontSize))
        }
        set {
            guard let newValue = newValue else {return}

            self.codeFontName = newValue.fontName
            self.codeFontSize = Int(newValue.pointSize)
        }
    }

    static var noteFont: Font! {
        get {
            if let fontName = self.fontName, let font = Font(name: fontName, size: CGFloat(self.fontSize)) {
                return font
            }

            return Font.systemFont(ofSize: CGFloat(self.fontSize))
        }
        set {
            guard let newValue = newValue else {
                self.fontName = nil
                return
            }
            
            self.fontName = newValue.fontName
            self.fontSize = Int(newValue.pointSize)
        }
    }
    
    static var fontColor: Color {
        get {
            if let returnFontColor = shared?.object(forKey: Constants.FontColorKey), let color = NSKeyedUnarchiver.unarchiveObject(with: returnFontColor as! Data) as? Color {
                return color
            } else {
                return self.DefaultFontColor
            }
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            shared?.set(data, forKey: Constants.FontColorKey)
        }
    }

    static var bgColor: Color {
        get {
            if let returnBgColor = shared?.object(forKey: Constants.BgColorKey), let color = NSKeyedUnarchiver.unarchiveObject(with: returnBgColor as! Data) as? Color {
                return color
            } else {
                return self.DefaultBgColor
            }
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            shared?.set(data, forKey: Constants.BgColorKey)
        }
    }
    
    static var externalEditor: String {
        get {
            let name = shared?.object(forKey: "externalEditorApp")
            if name != nil && (name as! String).count > 0 {
                return name as! String
            } else {
                return "TextEdit"
            }
        }
        set {
            shared?.set(newValue, forKey: "externalEditorApp")
        }
    }

    static var horizontalOrientation: Bool {
        get {
            if let returnMode = shared?.object(forKey: Constants.TableOrientation) {
                return returnMode as! Bool
            } else {
                return false
            }
        }
        set {
            shared?.set(newValue, forKey: Constants.TableOrientation)
        }
    }
    
    static var iCloudDocumentsContainer: URL? {
        get {
            if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents").standardized {
                if (!FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil)) {
                    do {
                        try FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
                        
                        return iCloudDocumentsURL.standardized
                    } catch {
                        print("Home directory creation: \(error)")
                    }
                } else {
                   return iCloudDocumentsURL.standardized
                }
            }

            return nil
        }
    }
    
    static var localDocumentsContainer: URL? {
        get {
            if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
 
            return nil
        }
    }
    
    static var storagePath: String? {
        get {
            if let storagePath = shared?.object(forKey: Constants.StoragePathKey) {
                if FileManager.default.isWritableFile(atPath: storagePath as! String) {
                    storageType = .custom
                    return storagePath as? String
                } else {
                    print("Storage path not accessible, settings resetted to default")
                }
            }

            if let iCloudDocumentsURL = self.iCloudDocumentsContainer {
                storageType = .iCloudDrive
                return iCloudDocumentsURL.path
            }
            
        #if os(iOS)
            if let localDocumentsContainer = localDocumentsContainer {
                storageType = .local
                return localDocumentsContainer.path
            }
            return nil
        #elseif CLOUDKIT && os(macOS)
            return nil
        #else
            if let localDocumentsContainer = localDocumentsContainer {
                storageType = .local
                return localDocumentsContainer.path
            }
            return nil
        #endif
        }
        set {
            shared?.set(newValue, forKey: Constants.StoragePathKey)
        }
    }

    public static var storageType: StorageType {
        get {
            if let type = shared?.object(forKey: Constants.StorageType) as? Int {
                return StorageType(rawValue: type) ?? .none
            }
            return .none
        }
        set {
            shared?.set(newValue.rawValue, forKey: Constants.StorageType)
        }
    }
    
    static var storageUrl: URL? {
        get {
            if let path = storagePath {
                let expanded = NSString(string: path).expandingTildeInPath

                return URL.init(fileURLWithPath: expanded, isDirectory: true).standardized
            }
            
            return nil
        }
    }

    static var preview: Bool {
        get {
            if let preview = shared?.object(forKey: Constants.Preview) {
                return preview as! Bool
            } else {
                return false
            }
        }
        set {
            shared?.set(newValue, forKey: Constants.Preview)
        }
    }
    
    static var lastSync: Date? {
        get {
            if let sync = shared?.object(forKey: "lastSync") {
                return sync as? Date
            } else {
                return nil
            }
        }
        set {
            shared?.set(newValue, forKey: "lastSync")
        }
    }
    
    static var hideOnDeactivate: Bool {
        get {
            if let hideOnDeactivate = shared?.object(forKey: Constants.HideOnDeactivate) {
                return hideOnDeactivate as! Bool
            } else {
                return false
            }
        }
        set {
            shared?.set(newValue, forKey: Constants.HideOnDeactivate)
        }
    }
    
    static var cellSpacing: Int {
        get {
            if let cellSpacing = shared?.object(forKey: Constants.CellSpacing) {
                return (cellSpacing as! NSNumber).intValue
            } else {
                return 33
            }
        }
        set {
            shared?.set(newValue, forKey: Constants.CellSpacing)
        }
    }
        
    static var cellViewFrameOriginY: CGFloat? {        
        get {
            if let value = shared?.object(forKey: Constants.CellFrameOriginY) {
                return value as? CGFloat
            }
            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.CellFrameOriginY)
        }
    }
    
    static var hidePreview: Bool {
        get {
            if let returnMode = shared?.object(forKey: Constants.HidePreviewKey) {
                return returnMode as! Bool
            } else {
                return false
            }
        }
        set {
            shared?.set(newValue, forKey: Constants.HidePreviewKey)
        }
    }
        
    static var sort: SortBy {
        get {
            if let result = shared?.object(forKey: "sortBy"), let sortBy = SortBy(rawValue: result as! String) {
                return sortBy
            } else {
                return .modificationDate
            }
        }
        set {
            shared?.set(newValue.rawValue, forKey: "sortBy")
        }
    }
    
    static var sortDirection: Bool {
        get {
            if let returnMode = shared?.object(forKey: "sortDirection") {
                return returnMode as! Bool
            } else {
                return true
            }
        }
        set {
            shared?.set(newValue, forKey: "sortDirection")
        }
    }
    
    static var hideSidebar: Bool {
        get {
            if let hide = shared?.object(forKey: "hideSidebar") {
                return hide as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: "hideSidebar")
        }
    }
    
    static var sidebarSize: CGFloat {
        get {
            if let size = shared?.object(forKey: "sidebarSize"), let width = size as? CGFloat {
                return width
            }
            
            #if os(iOS)
                return 0
            #else
                return 250
            #endif
        }
        set {
            shared?.set(newValue, forKey: "sidebarSize")
        }
    }
    
    static var hideRealSidebar: Bool {
        get {
            if let hide = shared?.object(forKey: "hideRealSidebar") {
                return hide as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: "hideRealSidebar")
        }
    }
    
    static var realSidebarSize: Int {
        get {
            if let size = shared?.object(forKey: "realSidebarSize") {
                return size as! Int
            }
            return 100
        }
        set {
            shared?.set(newValue, forKey: "realSidebarSize")
        }
    }
    
    static var codeBlockHighlight: Bool {
        get {
            if let highlight = shared?.object(forKey: Constants.codeBlockHighlight) {
                return highlight as! Bool
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.codeBlockHighlight)
        }
    }

    static var indentedCodeBlockHighlighting: Bool {
        get {
            if let highlight = shared?.object(forKey: Constants.IndentedCodeBlockHighlighting) {
                return highlight as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.IndentedCodeBlockHighlighting)
        }
    }

    static var lastSelectedURL: URL? {
        get {
            if let url = shared?.url(forKey: Constants.LastSelectedPath) {
                return url
            }
            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.LastSelectedPath)
        }
    }
    
    static var liveImagesPreview: Bool {
        get {
            if let result = shared?.object(forKey: Constants.LiveImagesPreview) {
                return result as! Bool
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.LiveImagesPreview)
        }
    }
    
    static var focusInEditorOnNoteSelect: Bool {
        get {
            if let result = shared?.object(forKey: "focusInEditorOnNoteSelect") {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: "focusInEditorOnNoteSelect")
        }
    }
    
    static var defaultLanguage: Int {
        get {
            if let dl = shared?.object(forKey: Constants.DefaultLanguageKey) as? Int {
                return dl
            }

            if let code = NSLocale.current.languageCode {
                return LanguageType.withCode(rawValue: code)
            }
            
            return 0
        }
        set {
            shared?.set(newValue, forKey: Constants.DefaultLanguageKey)
        }
    }
    
    static var restoreCursorPosition: Bool {
        get {
            if let result = shared?.object(forKey: Constants.RestoreCursorPosition) {
                return result as! Bool
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.RestoreCursorPosition)
        }
    }
    
    static var nightModeAuto: Bool {
        get {
            if let result = shared?.object(forKey: Constants.NightModeAuto) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.NightModeAuto)
        }
    }
    
    #if os(iOS)
        static var nightModeType: NightMode {
            get {
                if let result = shared?.object(forKey: Constants.NightModeType) {
                    return NightMode(rawValue: result as! Int) ?? .disabled
                }
                return NightMode(rawValue: 0x00) ?? .disabled
            }
            set {
                shared?.set(newValue.rawValue, forKey: Constants.NightModeType)
            }
        }
    #endif
    
    static var maxNightModeBrightnessLevel: Float {
        get {
            if let result = shared?.object(forKey: Constants.NightModeBrightnessLevel) {
                return result as! Float
            }
            return 35
        }
        set {
            shared?.set(newValue, forKey: Constants.NightModeBrightnessLevel)
        }
    }
    
    static var autocloseBrackets: Bool {
        get {
            if let result = shared?.object(forKey: Constants.AutocloseBrackets) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.AutocloseBrackets)
        }
    }
    
    static var lastProject: Int {
        get {
            if let lastProject = shared?.object(forKey: Constants.LastProject) {
                return lastProject as! Int
            } else {
                return 0
            }
        }
        set {
            shared?.set(newValue, forKey: Constants.LastProject)
        }
    }
    
    static var showDockIcon: Bool {
        get {
            if let result = shared?.object(forKey: Constants.ShowDockIcon) {
                return result as! Bool
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.ShowDockIcon)
        }
    }
    
    static var archiveDirectory: URL? {
        get {
            #if os(OSX)
            if let path = shared?.object(forKey: Constants.ArchiveDirectoryKey) as? String {
                var isDirectory = ObjCBool(true)
                let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

                if (exists && isDirectory.boolValue) {
                    return URL(fileURLWithPath: path, isDirectory: true)
                } else {
                    self.archiveDirectory = nil
                    print("Archive path not accessible, settings resetted to default")
                }
            }
            #endif

            if var archive = storageUrl?.appendingPathComponent("Archive", isDirectory: true) {
                
            #if os(iOS)
                archive = archive.resolvingSymlinksInPath()
            #endif
                
                if !FileManager.default.fileExists(atPath: archive.path) {
                    do {
                        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: false, attributes: nil)
                        self.archiveDirectory = archive
                        return archive
                    } catch {
                        print(error)
                    }
                } else {
                    self.archiveDirectory = archive.standardized
                    return archive
                }
            }
            
            return nil
        }
        
        set {
            if let url = newValue {
                shared?.set(url.path, forKey: Constants.ArchiveDirectoryKey)
            } else {
                shared?.set(nil, forKey: Constants.ArchiveDirectoryKey)
            }
        }
    }
    
    static var editorLineSpacing: Float {
        get {
            #if os(iOS)
            return 5
            #endif
            
            if let result = shared?.object(forKey: Constants.LineSpacingEditorKey) as? Float {
                return Float(Int(result))
            }
            
            return 4
        }
        set {
            shared?.set(newValue, forKey: Constants.LineSpacingEditorKey)
        }
    }

    static var imagesWidth: Float {
        get {
            if let result = shared?.object(forKey: Constants.ImagesWidthKey) {
                return result as! Float
            }
            return 300
        }
        set {
            shared?.set(newValue, forKey: Constants.ImagesWidthKey)
        }
    }

    static var lineWidth: Float {
        get {
            if let result = shared?.object(forKey: Constants.LineWidthKey) {
                return result as! Float
            }
            return 700
        }
        set {
            shared?.set(newValue, forKey: Constants.LineWidthKey)
        }
    }
    
    static var textMatchAutoSelection: Bool {
        get {
            if let result = shared?.object(forKey: Constants.TextMatchAutoSelection) {
                return result as! Bool
            }
            
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.TextMatchAutoSelection)
        }
    }
    
    static var continuousSpellChecking: Bool {
        get {
            if let result = shared?.object(forKey: Constants.ContinuousSpellChecking) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.ContinuousSpellChecking)
        }
    }
    
    static var grammarChecking: Bool {
        get {
            if let result = shared?.object(forKey: Constants.GrammarChecking) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.GrammarChecking)
        }
    }
    
    static var smartInsertDelete: Bool {
        get {
            if let result = shared?.object(forKey: Constants.SmartInsertDelete) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.SmartInsertDelete)
        }
    }
    
    static var automaticSpellingCorrection: Bool {
        get {
            if let result = shared?.object(forKey: Constants.AutomaticSpellingCorrection) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.AutomaticSpellingCorrection)
        }
    }
    
    static var automaticQuoteSubstitution: Bool {
        get {
            if let result = shared?.object(forKey: Constants.AutomaticQuoteSubstitution) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.AutomaticQuoteSubstitution)
        }
    }
    
    static var automaticDataDetection: Bool {
        get {
            if let result = shared?.object(forKey: Constants.AutomaticDataDetection) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.AutomaticDataDetection)
        }
    }
    
    static var automaticLinkDetection: Bool {
        get {
            if let result = shared?.object(forKey: Constants.AutomaticLinkDetection) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.AutomaticLinkDetection)
        }
    }
        
    static var automaticTextReplacement: Bool {
        get {
            if let result = shared?.object(forKey: Constants.AutomaticTextReplacement) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.AutomaticTextReplacement)
        }
    }
    
    static var automaticDashSubstitution: Bool {
        get {
            if let result = shared?.object(forKey: Constants.AutomaticDashSubstitution) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.AutomaticDashSubstitution)
        }
    }

    static var isHiddenSidebar: Bool {
        get {
            if let result = shared?.object(forKey: Constants.HideSidebar) {
                return result as! Bool
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.HideSidebar)
        }
    }
    
    static var shouldFocusSearchOnESCKeyDown: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.shouldFocusSearchOnESCKeyDown) as? Bool {
                return result
            }
            return true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.shouldFocusSearchOnESCKeyDown)
        }
    }
    
    static var showInMenuBar: Bool {
        get {
            if let result = shared?.object(forKey: Constants.ShowInMenuBar) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.ShowInMenuBar)
        }
    }
    
    static var fileContainer: NoteContainer {
        get {
            #if SHARE_EXT
                let defaults = UserDefaults.init(suiteName: "group.es.fsnot.user.defaults")
                if let result = defaults?.object(forKey: Constants.SharedContainerKey) as? Int, let container = NoteContainer(rawValue: result) {
                    return container
                }
            #endif

            if let result = shared?.object(forKey: Constants.NoteContainer) as? Int, let container = NoteContainer(rawValue: result) {
                return container
            }
            return .none
        }
        set {
            #if os(iOS)
            UserDefaults.init(suiteName: "group.es.fsnot.user.defaults")?.set(newValue.rawValue, forKey: Constants.SharedContainerKey)
            #endif

            shared?.set(newValue.rawValue, forKey: Constants.NoteContainer)
        }
    }

    static var projects: [URL] {
        get {
            guard let defaults = UserDefaults.init(suiteName: "group.es.fsnot.user.defaults") else { return [] }

            if let result = defaults.object(forKey: Constants.ProjectsKey) as? Data, let urls = NSKeyedUnarchiver.unarchiveObject(with: result) as? [URL] {
                return urls
            }

            return []
        }
        set {
            guard let defaults = UserDefaults.init(suiteName: "group.es.fsnot.user.defaults") else { return }

            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            defaults.set(data, forKey: Constants.ProjectsKey)
        }
    }

    static var importURLs: [URL] {
        get {
            guard let defaults = UserDefaults.init(suiteName: "group.es.fsnot.user.defaults") else { return [] }

            if let result = defaults.object(forKey: Constants.ImportURLsKey) as? Data, let urls = NSKeyedUnarchiver.unarchiveObject(with: result) as? [URL] {
                return urls
            }

            return []
        }
        set {
            guard let defaults = UserDefaults.init(suiteName: "group.es.fsnot.user.defaults") else { return }

            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            defaults.set(data, forKey: Constants.ImportURLsKey)
        }
    }

    static var fileFormat: NoteType {
        get {
            if let result = shared?.object(forKey: Constants.NoteType) as? Int {
                return NoteType.withTag(rawValue: result)
            }
            return .Markdown
        }
        set {
            shared?.set(newValue.tag, forKey: Constants.NoteType)
        }
    }

    static var noteExtension: String {
        get {
            if let result = shared?.object(forKey: Constants.NoteExtension) as? String {
                return result
            }

            return "markdown"
        }
        set {
            shared?.set(newValue, forKey: Constants.NoteExtension)
        }
    }

    static var previewFontSize: Int {
        get {
            if let result = shared?.object(forKey: Constants.PreviewFontSize) as? Int {
                return result
            }
            return 11
        }
        set {
            shared?.set(newValue, forKey: Constants.PreviewFontSize)
        }
    }

    static var hidePreviewImages: Bool {
        get {
            if let result = shared?.object(forKey: Constants.HidePreviewImages) as? Bool {
                return result
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.HidePreviewImages)
        }
    }

    static var masterPasswordHint: String {
        get {
            if let hint = shared?.object(forKey: Constants.MasterPasswordHint) as? String {
                return hint
            }
            return String()
        }
        set {
            shared?.set(newValue, forKey: Constants.MasterPasswordHint)
        }
    }

    static var lockOnSleep: Bool {
        get {
            if let result = shared?.object(forKey: Constants.LockOnSleep) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.LockOnSleep)
        }
    }

    static var lockOnScreenActivated: Bool {
        get {
            if let result = shared?.object(forKey: Constants.LockOnScreenActivated) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.LockOnScreenActivated)
        }
    }

    static var lockOnUserSwitch: Bool {
        get {
            if let result = shared?.object(forKey: Constants.LockAfterUserSwitch) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.LockAfterUserSwitch)
        }
    }

    static var allowTouchID: Bool {
        get {
            if NSClassFromString("NSTouchBar") == nil {
                return false
            }

            if let result = shared?.object(forKey: Constants.AllowTouchID) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.AllowTouchID)
        }
    }

    static var savePasswordInKeychain: Bool {
        get {
            if let result = shared?.object(forKey: Constants.SaveInKeychain) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.SaveInKeychain)
        }
    }

    static var hideDate: Bool {
        get {
            if let result = shared?.object(forKey: Constants.HideDate) as? Bool {
                return result
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.HideDate)
        }
    }

    static var spacesInsteadTabs: Bool {
        get {
            if let result = shared?.object(forKey: Constants.SpacesInsteadTabs) as? Bool {
                return result
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.SpacesInsteadTabs)
        }
    }

    static var firstLineAsTitle: Bool {
        get {
            if let result = shared?.object(forKey: Constants.FirstLineAsTitle) as? Bool {
                return result
            }

            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.FirstLineAsTitle)
        }
    }

    static var marginSize: Float {
        get {
            if let result = shared?.object(forKey: Constants.MarginSizeKey) {
                return result as! Float
            }
            return 20
        }
        set {
            shared?.set(newValue, forKey: Constants.MarginSizeKey)
        }
    }

    static var markdownPreviewCSS: URL? {
        get {
            if let path = shared?.object(forKey: Constants.MarkdownPreviewCSS) as? String,
                let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {

                if FileManager.default.fileExists(atPath: path) {
                    return URL(string: "file://" + encodedPath)
                }
            }
            
            return nil
        }
        set {
            if let url = newValue {
                shared?.set(url.path, forKey: Constants.MarkdownPreviewCSS)
            } else {
                shared?.set(nil, forKey: Constants.MarkdownPreviewCSS)
            }
        }
    }

    static var gitStorage: URL {
        get {
            if let repositories = shared?.url(forKey: Constants.GitStorage) {
                if !FileManager.default.fileExists(atPath: repositories.path) {
                    try? FileManager.default.createDirectory(at: repositories, withIntermediateDirectories: true, attributes: nil)
                }

                return repositories
            }

            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let repositories = applicationSupport.appendingPathComponent("Repositories")

            if !FileManager.default.fileExists(atPath: repositories.path) {
                try? FileManager.default.createDirectory(at: repositories, withIntermediateDirectories: true, attributes: nil)
            }

            return repositories
        }
        set {
            shared?.set(newValue, forKey: Constants.GitStorage)
        }
    }

    static var snapshotsInterval: Int {
        get {
            if let interval = shared?.object(forKey: Constants.SnapshotsInterval) as? Int {
                return interval
            }

            return self.DefaultSnapshotsInterval
        }
        set {
            shared?.set(newValue, forKey: Constants.SnapshotsInterval)
        }
    }

    static var snapshotsIntervalMinutes: Int {
        get {
            if let interval = shared?.object(forKey: Constants.SnapshotsIntervalMinutes) as? Int {
                return interval
            }

            return self.DefaultSnapshotsIntervalMinutes
        }
        set {
            shared?.set(newValue, forKey: Constants.SnapshotsIntervalMinutes)
        }
    }

    static var backupManually: Bool {
        get {
            if let returnMode = shared?.object(forKey: Constants.BackupManually) as? Bool {
                return returnMode
            } else {
                return true
            }
        }
        set {
            shared?.set(newValue, forKey: Constants.BackupManually)
        }
    }

    static var fullScreen: Bool {
        get {
            if let result = shared?.object(forKey: Constants.FullScreen) as? Bool {
                return result
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.FullScreen)
        }
    }

    static var inlineTags: Bool {
        get {
            if let result = shared?.object(forKey: Constants.InlineTags) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.InlineTags)
        }
    }

    static var copyWelcome: Bool {
        get {
            if let result = shared?.object(forKey: Constants.Welcome) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.Welcome)
        }
    }

    static var mathJaxPreview: Bool {
        get {
            if let result = shared?.object(forKey: Constants.MathJaxPreview) as? Bool {
                return result
            }

            #if os(iOS)
            return true
            #else
            return false
            #endif
        }
        set {
            shared?.set(newValue, forKey: Constants.MathJaxPreview)
        }
    }

    static var sidebarVisibilityInbox: Bool {
        get {
            if let result = shared?.object(forKey: "sidebarVisibilityInbox") as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: "sidebarVisibilityInbox")
        }
    }

    static var sidebarVisibilityNotes: Bool {
        get {
            if let result = shared?.object(forKey: "sidebarVisibilityNotes") as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: "sidebarVisibilityNotes")
        }
    }

    static var sidebarVisibilityTodo: Bool {
        get {
            if let result = shared?.object(forKey: "sidebarVisibilityTodo") as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: "sidebarVisibilityTodo")
        }
    }

    static var sidebarVisibilityArchive: Bool {
        get {
            if let result = shared?.object(forKey: "sidebarVisibilityArchive") as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: "sidebarVisibilityArchive")
        }
    }

    static var sidebarVisibilityTrash: Bool {
        get {
            if let result = shared?.object(forKey: "sidebarVisibilityTrash") as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: "sidebarVisibilityTrash")
        }
    }

    static var crashedLastTime: Bool {
        get {
            if let result = shared?.object(forKey: Constants.CrashedLastTime) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.CrashedLastTime)
        }
    }

    static var lastNews: Date? {
        get {
            if let sync = shared?.object(forKey: "lastNews") {
                return sync as? Date
            } else {
                return nil
            }
        }
        set {
            shared?.set(newValue, forKey: "lastNews")
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

    static var autoInsertHeader: Bool {
        get {
            if let result = shared?.object(forKey: Constants.AutoInsertHeader) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.AutoInsertHeader)
        }
    }
}
