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
    
    static var apiPath = "https://api.fsnot.es/"
    static var webPath = "https://p.fsnot.es/"

#if os(OSX)
    typealias Color = NSColor
    typealias Image = NSImage
    typealias Font = NSFont

    public static var shared: UserDefaults? = UserDefaults.standard
    public static var DefaultFontSize = 14
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
        static let AskCommitMessage = "askCommitMessage"
        static let ApiBookmarksData = "apiBookmarksData"
        static let AutoInsertHeader = "autoInsertHeader"
        static let AutoVersioning = "autoVersioning"
        static let AutomaticSpellingCorrection = "automaticSpellingCorrection"
        static let AutomaticQuoteSubstitution = "automaticQuoteSubstitution"
        static let AutomaticDataDetection = "automaticDataDetection"
        static let AutomaticLinkDetection = "automaticLinkDetection"
        static let AutomaticTextReplacement = "automaticTextReplacement"
        static let AutomaticDashSubstitution = "automaticDashSubstitution"
        static let AutomaticConflictsResolution = "automaticConflictsResolution"
        static let BackupManually = "backupManually"
        static let BgColorKey = "bgColorKeyed"
        static let CacheDiff = "cacheDiff"
        static let CellSpacing = "cellSpacing"
        static let CellFrameOriginY = "cellFrameOriginY"
        static let ClickableLinks = "clickableLinks"
        static let CodeFontNameKey = "codeFont"
        static let CodeFontSizeKey = "codeFontSize"
        static let codeBlockHighlight = "codeBlockHighlight"
        static let CodeBlocksWithSyntaxHighlighting = "codeBlocksWithSyntaxHighlighting"
        static let codeTheme = "codeTheme"
        static let ContinuousSpellChecking = "continuousSpellChecking"
        static let CrashedLastTime = "crashedLastTime"
        static let CustomWebServer = "customWebServer"
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
        static let GitUsername = "gitUsername"
        static let GitPassword = "gitPassword"
        static let GitOrigin = "gitOrigin"
        static let GitPrivateKeyData = "gitPrivateKeyData"
        static let GitPasspharse = "gitPasspharse"
        static let HideDate = "hideDate"
        static let HideOnDeactivate = "hideOnDeactivate"
        static let HideSidebar = "hideSidebar"
        static let HidePreviewKey = "hidePreview"
        static let HidePreviewImages = "hidePreviewImages"
        static let iCloudDrive = "iCloudDrive"
        static let ImagesWidthKey = "imagesWidthKey"
        static let IndentedCodeBlockHighlighting = "IndentedCodeBlockHighlighting"
        static let IndentUsing = "indentUsing"
        static let InlineTags = "inlineTags"
        static let LastCommitMessage = "lastCommitMessage"
        static let LastNews = "lastNews"
        static let LastSelectedPath = "lastSelectedPath"
        static let LastScreenX = "lastScreenX"
        static let LastScreenY = "lastScreenY"
        static let LastSidebarItem = "lastSidebarItem"
        static let LastProjectURL = "lastProjectUrl"
        static let LineSpacingEditorKey = "lineSpacingEditor"
        static let LineWidthKey = "lineWidth"
        static let LiveImagesPreview = "liveImagesPreview"
        static let LockOnSleep = "lockOnSleep"
        static let LockOnScreenActivated = "lockOnScreenActivated"
        static let LockAfterIDLE = "lockAfterIdle"
        static let LockAfterUserSwitch = "lockAfterUserSwitch"
        static let MarginSizeKey = "marginSize"
        static let MasterPasswordHint = "masterPasswordHint"
        static let MathJaxPreview = "mathJaxPreview"
        static let NightModeType = "nightModeType"
        static let NightModeAuto = "nightModeAuto"
        static let NightModeBrightnessLevel = "nightModeBrightnessLevel"
        static let NonContiguousLayout = "allowsNonContiguousLayout"
        static let NoteContainer = "noteContainer"
        static let Preview = "preview"
        static let PreviewFontSize = "previewFontSize"
        static let ProjectsKey = "projects"
        static let ProjectsKeyNew = "ProjectsKeyNew"
        static let RecentSearches = "recentSearches"
        static let PullInterval = "pullInterval"
        static let SaveInKeychain = "saveInKeychain"
        static let SearchHighlight = "searchHighlighting"
        static let SeparateRepo = "separateRepo"
        static let SftpHost = "sftpHost"
        static let SftpPort = "sftpPort"
        static let SftpPath = "sftpPath"
        static let SftpPasspharse = "sftpPassphrase"
        static let SftpWeb = "sftpWeb"
        static let SftpUsername = "sftpUsername"
        static let SftpPassword = "sftpPassword"
        static let SftpKeysAccessData = "sftpKeysAccessData"
        static let SftpUploadBookmarksData = "sftpUploadBookmarksData"
        static let SharedContainerKey = "sharedContainer"
        static let ShowDockIcon = "showDockIcon"
        static let shouldFocusSearchOnESCKeyDown = "shouldFocusSearchOnESCKeyDown"
        static let ShowInMenuBar = "showInMenuBar"
        static let SmartInsertDelete = "smartInsertDelete"
        static let SnapshotsInterval = "snapshotsInterval"
        static let SnapshotsIntervalMinutes = "snapshotsIntervalMinutes"
        static let SortBy = "sortBy"
        static let SoulverPreview = "soulverPreview"
        static let StorageType = "storageType"
        static let StoragePathKey = "storageUrl"
        static let TableOrientation = "isUseHorizontalMode"
        static let TextMatchAutoSelection = "textMatchAutoSelection"
        static let TrashKey = "trashKey"
        static let UploadKey = "uploadKey"
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
            if let returnFontSize = shared?.object(forKey: Constants.FontSizeKey) as? Int {
                return returnFontSize
            } else {
                return self.DefaultFontSize
            }
        }
        set {
            shared?.set(newValue, forKey: Constants.FontSizeKey)
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
            if var path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {

#if os(iOS)
                if path.starts(with: "/var") {
                    path = "/private\(path)"
                }
#endif

                return URL(fileURLWithPath: path, isDirectory: true)
            }
 
            return nil
        }
    }
    
    static var customStoragePath: String? {
        get {
            if let storagePath = shared?.object(forKey: Constants.StoragePathKey) {
                if FileManager.default.isWritableFile(atPath: storagePath as! String) {
                    storageType = .custom
                    return storagePath as? String
                } else {
                    print("Storage path not accessible, settings resetted to default")
                }
            }
            
            return nil
        }
        
        set {
            shared?.set(newValue, forKey: Constants.StoragePathKey)
        }
    }
    
    static var storagePath: String? {
        get {
            if let customStoragePath = self.customStoragePath {
                return customStoragePath
            }

            if let iCloudDocumentsURL = self.iCloudDocumentsContainer {
                storageType = .iCloudDrive
                return iCloudDocumentsURL.path
            }

            if let localDocumentsContainer = localDocumentsContainer {
                storageType = .local
                return localDocumentsContainer.path
            }

            return nil
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
    
    static var lastProjectURL: URL? {
        get {
            if let lastProject = shared?.url(forKey: Constants.LastProjectURL) {
                return lastProject
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.LastProjectURL)
        }
    }

    static var lastSidebarItem: Int? {
        get {
            if let index = shared?.object(forKey: Constants.LastSidebarItem) as? Int {
                return index
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.LastSidebarItem)
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
    
    static var editorLineSpacing: Float {
        get {
            if let result = shared?.object(forKey: Constants.LineSpacingEditorKey) as? Float {
                return Float(Int(result))
            } else {
                #if os(iOS)
                    return 6
                #else
                    return 4
                #endif
            }
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
    
    static var automaticConflictsResolution: Bool {
        get {
            if let result = UserDefaults.standard.object(forKey: Constants.AutomaticConflictsResolution) as? Bool {
                return result
            }
            return false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.AutomaticConflictsResolution)
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

    static var fileFormat: NoteType {
        get {
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

    static var indentUsing: Int {
        get {
            if let result = shared?.integer(forKey: Constants.IndentUsing) {
                return result
            }

            return 0
        }
        set {
            shared?.set(newValue, forKey: Constants.IndentUsing)
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
    
    static var gitUsername: String? {
        get {
            if let result = shared?.object(forKey: Constants.GitUsername) as? String {
                if result.count == 0 {
                    return nil
                }
                
                return result
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.GitUsername)
        }
    }
    
    static var gitPassword: String? {
        get {
            if let result = shared?.object(forKey: Constants.GitPassword) as? String {
                if result.count == 0 {
                    return nil
                }
                
                return result
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.GitPassword)
        }
    }
    
    static var gitOrigin: String? {
        get {
            if let result = shared?.object(forKey: Constants.GitOrigin) as? String {
                if result.count == 0 {
                    return nil
                }
                
                return result
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.GitOrigin)
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
    
    static var pullInterval: Int {
        get {
            if let interval = shared?.object(forKey: Constants.PullInterval) as? Int {
                return interval
            }

            return 10
        }
        set {
            shared?.set(newValue, forKey: Constants.PullInterval)
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

            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.MathJaxPreview)
        }
    }
    
    static var soulverPreview: Bool {
        get {
            if #unavailable(OSX 10.15, iOS 14.0) {
                return false
            }
            
            if let result = shared?.object(forKey: Constants.SoulverPreview) as? Bool {
                return result
            }

            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.SoulverPreview)
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

    static var sidebarVisibilityUntagged: Bool {
        get {
            if let result = shared?.object(forKey: "sidebarVisibilityUntagged") as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: "sidebarVisibilityUntagged")
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

            return .autoRename
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

    static var nonContiguousLayout: Bool {
        get {
            if let result = shared?.object(forKey: Constants.NonContiguousLayout), let data = result as? Bool {
                return data
            }

            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.NonContiguousLayout)
        }
    }

    static var codeBlocksWithSyntaxHighlighting: Bool {
        get {
            if let result = shared?.object(forKey: Constants.CodeBlocksWithSyntaxHighlighting) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.CodeBlocksWithSyntaxHighlighting)
        }
    }

    static var lastScreenX: Int? {
        get {
            if let value = shared?.object(forKey: Constants.LastScreenX) as? Int {
                return value
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.LastScreenX)
        }
    }

    static var lastScreenY: Int? {
        get {
            if let value = shared?.object(forKey: Constants.LastScreenY) as? Int {
                return value
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.LastScreenY)
        }
    }

    static var recentSearches: [String]? {
        get {
            if let value = shared?.array(forKey: Constants.RecentSearches) as? [String] {
                return value
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.RecentSearches)
        }
    }

    static var searchHighlight: Bool {
        get {
            if let result = shared?.object(forKey: Constants.SearchHighlight) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.SearchHighlight)
        }
    }

    static var autoVersioning: Bool {
        get {
            if let result = shared?.object(forKey: Constants.AutoVersioning) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.AutoVersioning)
        }
    }
    
    static var iCloudDrive: Bool {
        get {
            if let result = shared?.object(forKey: Constants.iCloudDrive) as? Bool {
                return result
            }
            return true
        }
        set {
            shared?.set(newValue, forKey: Constants.iCloudDrive)
        }
    }
    
    static var customWebServer: Bool {
        get {
            if let result = shared?.object(forKey: Constants.CustomWebServer) as? Bool {
                return result
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.CustomWebServer)
        }
    }
    
    static var sftpHost: String {
        get {
            if let result = shared?.object(forKey: Constants.SftpHost) as? String {
                return result
            }

            return ""
        }
        set {
            shared?.set(newValue, forKey: Constants.SftpHost)
        }
    }
    
    static var sftpPort: Int32 {
        get {
            if let result = shared?.object(forKey: Constants.SftpPort) as? Int32 {
                return result
            }

            return 22
        }
        set {
            shared?.set(newValue, forKey: Constants.SftpPort)
        }
    }
    
    static var sftpUsername: String {
        get {
            if let result = shared?.object(forKey: Constants.SftpUsername) as? String {
                return result
            }

            return ""
        }
        set {
            shared?.set(newValue, forKey: Constants.SftpUsername)
        }
    }
    
    static var sftpPassword: String {
        get {
            if let result = shared?.object(forKey: Constants.SftpPassword) as? String {
                return result
            }

            return ""
        }
        set {
            shared?.set(newValue, forKey: Constants.SftpPassword)
        }
    }
    
    static var sftpPath: String? {
        get {
            if let result = shared?.object(forKey: Constants.SftpPath) as? String {
                if result.count == 0 {
                    return nil
                }
                
                let suffix = result.hasSuffix("/") ? "" : "/"
                return result + suffix
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.SftpPath)
        }
    }
    
    static var sftpPassphrase: String {
        get {
            if let result = shared?.object(forKey: Constants.SftpPasspharse) as? String {
                return result
            }

            return ""
        }
        set {
            shared?.set(newValue, forKey: Constants.SftpPasspharse)
        }
    }
    
    static var sftpWeb: String? {
        get {
            if let result = shared?.object(forKey: Constants.SftpWeb) as? String {
                if result.count == 0 {
                    return nil
                }
                
                if result.last != "/" {
                    return result + "/"
                }
                
                return result
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.SftpWeb)
        }
    }
    
    static var sftpAccessData: Data? {
        get {
            return shared?.data(forKey: Constants.SftpKeysAccessData)
        }
        set {
            shared?.set(newValue, forKey: Constants.SftpKeysAccessData)
        }
    }
    
    static var sftpUploadBookmarksData: Data? {
        get {
            return shared?.data(forKey: Constants.SftpUploadBookmarksData)
        }
        set {
            shared?.set(newValue, forKey: Constants.SftpUploadBookmarksData)
        }
    }
    
    static var apiBookmarksData: Data? {
        get {
            return shared?.data(forKey: Constants.ApiBookmarksData)
        }
        set {
            shared?.set(newValue, forKey: Constants.ApiBookmarksData)
        }
    }
    
    static var gitPrivateKeyData: Data? {
        get {
            return shared?.data(forKey: Constants.GitPrivateKeyData)
        }
        set {
            shared?.set(newValue, forKey: Constants.GitPrivateKeyData)
        }
    }
    
    static var gitPassphrase: String {
        get {
            if let result = shared?.object(forKey: Constants.GitPasspharse) as? String {
                return result
            }

            return ""
        }
        set {
            shared?.set(newValue, forKey: Constants.GitPasspharse)
        }
    }
    
    static var uploadKey: String {
        get {
            if let result = shared?.object(forKey: Constants.UploadKey) as? String, result.count > 0 {
                return result
            }

            let key = String.random(length: 20)
            shared?.set(key, forKey: Constants.UploadKey)
            
            return key
        }
        set {
            shared?.set(newValue, forKey: Constants.UploadKey)
        }
    }
    
    static var clickableLinks: Bool {
        get {
            if let highlight = shared?.object(forKey: Constants.ClickableLinks) {
                return highlight as! Bool
            }
            
            #if os(iOS)
                return true
            #else
                return false
            #endif
        }
        set {
            shared?.set(newValue, forKey: Constants.ClickableLinks)
        }
    }
    
    static var trashURL: URL? {
        get {
            if let trashUrl = shared?.url(forKey: Constants.TrashKey) {
                return trashUrl
            }

            return nil
        }
        set {
            shared?.set(newValue, forKey: Constants.TrashKey)
        }
    }
    
    static var separateRepo: Bool {
        get {
            if let result = shared?.object(forKey: Constants.SeparateRepo) as? Bool {
                return result
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.SeparateRepo)
        }
    }
    
    static var askCommitMessage: Bool {
        get {
            if let result = shared?.object(forKey: Constants.AskCommitMessage) as? Bool {
                return result
            }
            return false
        }
        set {
            shared?.set(newValue, forKey: Constants.AskCommitMessage)
        }
    }
    
    static var lastCommitMessage: String? {
        get {
            if let result = shared?.object(forKey: Constants.LastCommitMessage) as? String, result.count > 0 {
                return result
            }
            
            return nil
        }
        
        set {
            shared?.set(newValue, forKey: Constants.LastCommitMessage)
        }
    }
    
    static var lightCodeTheme: String {
        get {
            if let theme = UserDefaults.standard.object(forKey: Constants.codeTheme) as? String {
                return theme
            }

            return "github"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.codeTheme)
        }
    }
    
    static var projects: [URL] {
        get {
            guard let defaults = UserDefaults.init(suiteName: "group.es.fsnot.user.defaults") else { return [] }

            if let data = defaults.data(forKey: Constants.ProjectsKeyNew), let urls = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSURL.self], from: data) as? [URL] {
                return urls
            }

            return []
        }
        set {
            guard let defaults = UserDefaults.init(suiteName: "group.es.fsnot.user.defaults") else { return }

            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                defaults.set(data, forKey: Constants.ProjectsKeyNew)
            }
        }
    }
}
