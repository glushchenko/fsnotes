//
//  ViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/20/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import MASShortcut
import FSNotesCore_macOS
import Foundation
import Shout
import UserNotifications
import WebKit

class ViewController: EditorViewController,
    NSSplitViewDelegate,
    NSOutlineViewDelegate,
    NSOutlineViewDataSource,
    NSTextFieldDelegate,
    UNUserNotificationCenterDelegate {
    
    // MARK: - Properties
    public var fsManager: FileSystemEventManager?
    public var projectSettingsViewController: ProjectSettingsViewController?

    private var isPreLoaded = false
    
    let storage = Storage.shared()
    
    private var sidebarTimer = Timer()
    private var selectRowTimer = Timer()

    private let searchQueue = OperationQueue()

    public static var gitQueue = OperationQueue()
    public static var gitQueueBusy: Bool = false
    public static var gitQueueOperationDate: Date?

    public var prevCommit: Commit?

    /* Git */
    private var updateViews = [Note]()

    var tagsScannerQueue = [Note]()

    @available(*, deprecated, message: "Remove after macOS 10.15 is no longer supported")
    public var printerLegacy: PrinterLegacy?

    override var representedObject: Any? {
        didSet { }  // Update the view, if already loaded.
    }

    // MARK: - IBOutlets
    @IBOutlet weak var nonSelectedLabel: NSTextField!

    @IBOutlet weak var splitView: EditorSplitView!
    @IBOutlet var editor: EditTextView!
    @IBOutlet weak var editAreaScroll: EditorScrollView!
    @IBOutlet weak var search: SearchTextField!
    @IBOutlet weak var notesTableView: NotesTableView!
    @IBOutlet var noteMenu: NSMenu!
    @IBOutlet weak var sidebarOutlineView: SidebarOutlineView!
    @IBOutlet weak var sidebarSplitView: NSSplitView!
    @IBOutlet weak var notesListCustomView: NSView!
    @IBOutlet weak var outlineHeader: OutlineHeaderView!
    @IBOutlet weak var showInSidebar: NSMenuItem!
    @IBOutlet weak var searchTopConstraint: NSLayoutConstraint!

    @IBOutlet weak var lockedFolder: NSTextField!
    @IBOutlet weak var newNoteButton: NSButton!
    @IBOutlet weak var titleLabel: TitleTextField! {
        didSet {
            let clickGesture = NSClickGestureRecognizer()
            clickGesture.target = self
            clickGesture.numberOfClicksRequired = 2
            clickGesture.buttonMask = 0x1
            clickGesture.action = #selector(switchTitleToEditMode)
            
            titleLabel.addGestureRecognizer(clickGesture)
        }
    }
    @IBOutlet weak var shareButton: NSButton!
    @IBOutlet weak var sortByOutlet: NSMenuItem!

    @IBOutlet weak var titleBarAdditionalView: NSVisualEffectView! {
        didSet {
            let layer = CALayer()
            layer.frame = titleBarAdditionalView.bounds
            layer.backgroundColor = .clear
            titleBarAdditionalView.wantsLayer = true
            titleBarAdditionalView.layer = layer
            titleBarAdditionalView.alphaValue = 0
        }
    }
    @IBOutlet weak var previewButton: NSButton! {
        didSet {
            previewButton.state = vcEditor?.isPreviewEnabled() == true ? .on : .off
        }
    }
    @IBOutlet weak var titleBarView: TitleBarView! {
        didSet {
            titleBarView.onMouseExitedClosure = { [weak self] in
                DispatchQueue.main.async {
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.35
                        self?.titleBarAdditionalView.alphaValue = 0
                        self?.titleLabel.backgroundColor = .clear
                    }, completionHandler: nil)
                }
            }
            titleBarView.onMouseEnteredClosure = { [weak self] in
                DispatchQueue.main.async {
                    guard self?.titleLabel.isEnabled == false || self?.titleLabel.isEditable == false else { return }
                    
                    if let note = self?.editor.note {
                        if note.isUnlocked() {
                            self?.lockUnlock.image = NSImage(named: NSImage.lockUnlockedTemplateName)
                        } else {
                            self?.lockUnlock.image = NSImage(named: NSImage.lockLockedTemplateName)
                        }
                    }

                    self?.lockUnlock.isHidden = (self?.editor.note == nil)

                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.35
                        self?.titleBarAdditionalView.alphaValue = 1
                    }, completionHandler: nil)
                }
            }
        }
    }

    @IBOutlet weak var lockUnlock: NSButton!

    @IBOutlet weak var sidebarScrollView: NSScrollView!
    @IBOutlet weak var notesScrollView: NSScrollView!

    @IBOutlet weak var menuChangeCreationDate: NSMenuItem!

    // MARK: - Overrides
    
    override func viewDidLoad() {
        if isPreLoaded {
            return
        }

        isPreLoaded = true

        if #available(macOS 12.0, *) {
            let image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil)
            var config = NSImage.SymbolConfiguration(textStyle: .body, scale: .large)
            config = config.applying(.init(paletteColors: [.systemTeal, .systemGray]))

            newNoteButton.image = image?.withSymbolConfiguration(config)
        } else {
            newNoteButton.image = NSImage(imageLiteralResourceName: "new_note_button").resize(to: CGSize(width: 20, height: 20))
        }

        configureShortcuts()
        configureDelegates()
        configureLayout()
        configureEditor()

        fsManager = FileSystemEventManager(storage: storage, delegate: self)
        fsManager?.start()

        loadBookmarks(data: UserDefaultsManagement.sftpAccessData)
        loadBookmarks(data: UserDefaultsManagement.gitPrivateKeyData)

        loadMoveMenu()
        loadSortBySetting()
        checkSidebarConstraint()

    #if CLOUD_RELATED_BLOCK
        registerKeyValueObserver()
    #endif

        ViewController.gitQueue.maxConcurrentOperationCount = 1

        notesTableView.doubleAction = #selector(self.doubleClickOnNotesTable)

        DispatchQueue.global().async {
            self.storage.loadInboxAndTrash()

            DispatchQueue.main.async {
                self.buildSearchQuery()
                self.configureSidebar()
                self.configureNoteList()
            }
        }
    }
    
    override func viewDidAppear() {
        // Restore window position

        if sidebarOutlineView.isFirstLaunch, let x = UserDefaultsManagement.lastScreenX, let y = UserDefaultsManagement.lastScreenY {
            view.window?.setFrameOrigin(NSPoint(x: x, y: y))

            UserDefaultsManagement.lastScreenX = nil
            UserDefaultsManagement.lastScreenY = nil
        }

        if UserDefaultsManagement.fullScreen {
            view.window?.toggleFullScreen(nil)
        }
    }

    public func preLoadProjectsData() {
        let projectsLoading = Date()
        let results = self.storage.getProjectDiffs()

        OperationQueue.main.addOperation {
            self.sidebarOutlineView.removeRows(projects: results.0)
            self.sidebarOutlineView.insertRows(projects: results.1)
            self.notesTableView.doVisualChanges(results: (results.2, results.3, []))
        }

        print("0. Projects diff loading finished in \(projectsLoading.timeIntervalSinceNow * -1) seconds")

        let diffLoading = Date()
        for project in self.storage.getProjects() {
            let changes = project.checkNotesCacheDiff()
            self.notesTableView.doVisualChanges(results: changes)
        }

        // Reload added projects
        self.fsManager?.restart()

        print("1. Notes diff loading finished in \(diffLoading.timeIntervalSinceNow * -1) seconds")

        let tagsPoint = Date()

        // Schedule git actions
        self.scheduleSnapshots()
        self.schedulePull()

        // Loads tags
        self.storage.loadNotesContent()

        DispatchQueue.main.async {
            if self.storage.isCrashedLastTime {

                // Unsafe – resets selected note
                self.restoreSidebar()
            }

            // Safe – only tags loading
            self.sidebarOutlineView.loadAllTags()
        }

        print("2. Tags loading finished in \(tagsPoint.timeIntervalSinceNow * -1) seconds")

        let highlightCachePoint = Date()
        for note in self.storage.noteList {
            if note.type == .Markdown {
                note.cache(backgroundThread: true)
            }
        }
        
        print("3. Notes attributes cache for \(self.storage.noteList.count) notes in \(highlightCachePoint.timeIntervalSinceNow * -1) seconds")

        let gitCachePoint = Date()
        self.cacheGitRepositories()
        print("4. git history cached in \(gitCachePoint.timeIntervalSinceNow * -1) seconds")

    }
    
    // MARK: - Initial configuration
    
    private func configureLayout() {
        dropTitle()

        editor.configure()
        notesTableView.setDraggingSourceOperationMask(.every, forLocal: false)
                
        if (UserDefaultsManagement.horizontalOrientation) {
            self.splitView.isVertical = false
        }

        self.menuChangeCreationDate.title = NSLocalizedString("Change Creation Date", comment: "Menu")

        self.shareButton.sendAction(on: .leftMouseDown)
        self.setTableRowHeight()

        self.sidebarOutlineView.sidebarItems = Sidebar().getList()
        self.sidebarOutlineView.reloadData()

        sidebarOutlineView.selectionHighlightStyle = .regular
        sidebarOutlineView.backgroundColor = .windowBackgroundColor

        self.sidebarSplitView.autosaveName = "SidebarSplitView"
        self.splitView.autosaveName = "EditorSplitView"

        notesScrollView.scrollerStyle = .overlay
        sidebarScrollView.scrollerStyle = .overlay

        if UserDefaultsManagement.appearanceType == .Custom {
            titleBarView.wantsLayer = true
            titleBarView.layer?.backgroundColor = UserDefaultsManagement.bgColor.cgColor
            titleLabel.backgroundColor = UserDefaultsManagement.bgColor
        }

        if let cell = search.cell as? NSSearchFieldCell {
            cell.searchButtonCell?.target = self
            cell.searchButtonCell?.action = #selector(openRecentPopup(_:))
        }

        DistributedNotificationCenter.default().addObserver(self, selector: #selector(onWakeNote(note:)), name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onSleepNote(note:)),
            name: NSWorkspace.willSleepNotification, object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onUserSwitch(note:)),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(onScreenLocked(note:)),
            name: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(onAccentColorChanged(note:)),
            name: NSNotification.Name(rawValue: "AppleColorPreferencesChangedNotification"),
            object: nil
        )

        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(onAccentColorChanged(note:)),
            name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"),
            object: nil
        )

    }

    public func restoreSidebar() {
        self.sidebarOutlineView.sidebarItems = Sidebar().getList()
        self.sidebarOutlineView.reloadData()

        self.storage.restoreProjectsExpandState()

        for project in self.storage.getProjects() {
            if project.isExpanded {
                self.sidebarOutlineView.expandItem(project)
            }
        }
    }


    public func configureSidebar() {
        if isVisibleSidebar() {
            self.restoreSidebar()

            if UserDefaultsManagement.lastSidebarItem != nil || UserDefaultsManagement.lastProjectURL != nil {
                if let lastSidebarItem = UserDefaultsManagement.lastSidebarItem {
                    let sidebarItem = self.sidebarOutlineView.sidebarItems?.first(where: { ($0 as? SidebarItem)?.type.rawValue == lastSidebarItem })
                    let item = self.sidebarOutlineView.row(forItem: sidebarItem)
                    if item > -1 {
                        self.sidebarOutlineView.selectRowIndexes([item], byExtendingSelection: false)
                    }
                } else if let lastURL = UserDefaultsManagement.lastProjectURL, let project = self.storage.getProjectBy(url: lastURL) {
                    let item = self.sidebarOutlineView.row(forItem: project)
                    if item > -1 {
                        self.sidebarOutlineView.selectRowIndexes([item], byExtendingSelection: false)
                    }
                }
            }
        }
    }
    
    private func configureNoteList() {
        updateTable() {            
            if UserDefaultsManagement.copyWelcome {
                DispatchQueue.main.async {
                    let welcome = self.storage.getProjects().first(where: { $0.label == "Welcome" })
                    let index = self.sidebarOutlineView.row(forItem: welcome)
                    self.sidebarOutlineView.selectRowIndexes([index], byExtendingSelection: false)
                }

                UserDefaultsManagement.copyWelcome = false
                return
            }

            DispatchQueue.main.async {

                self.restoreOpenedWindows()
                self.importAndCreate()

                DispatchQueue.global().async {
                    self.preLoadProjectsData()
                }
            }
        }
    }

    private func configureEditor() {
        self.editor.isGrammarCheckingEnabled = UserDefaultsManagement.grammarChecking
        self.editor.isContinuousSpellCheckingEnabled = UserDefaultsManagement.continuousSpellChecking
        self.editor.smartInsertDeleteEnabled = UserDefaultsManagement.smartInsertDelete
        self.editor.isAutomaticSpellingCorrectionEnabled = UserDefaultsManagement.automaticSpellingCorrection
        self.editor.isAutomaticQuoteSubstitutionEnabled = UserDefaultsManagement.automaticQuoteSubstitution
        self.editor.isAutomaticDataDetectionEnabled = UserDefaultsManagement.automaticDataDetection
        self.editor.isAutomaticLinkDetectionEnabled = UserDefaultsManagement.automaticLinkDetection
        self.editor.isAutomaticTextReplacementEnabled = UserDefaultsManagement.automaticTextReplacement
        self.editor.isAutomaticDashSubstitutionEnabled = UserDefaultsManagement.automaticDashSubstitution

        if UserDefaultsManagement.appearanceType != AppearanceType.Custom {
            if #available(OSX 10.13, *) {
                self.editor?.linkTextAttributes = [
                    .foregroundColor:  NSColor.init(named: "link")!
                ]
            }
        }

        self.editor.usesFindBar = true
        self.editor.isIncrementalSearchingEnabled = true

        editor.initTextStorage()
        editor.editorViewController = self
        
        self.editor.viewDelegate = self
        
        // configure editor view controller
        
        vcEditor = editor
        vcTitleLabel = titleLabel
        vcEditorScrollView = editAreaScroll
        vcNonSelectedLabel = nonSelectedLabel
        
        super.initView()
    }

    private func configureShortcuts() {
        MASShortcutMonitor.shared().register(UserDefaultsManagement.newNoteShortcut, withAction: {
            self.makeNoteShortcut()
        })
        
        MASShortcutMonitor.shared().register(UserDefaultsManagement.searchNoteShortcut, withAction: {
            self.searchShortcut()
        })
        
        MASShortcutMonitor.shared().register(UserDefaultsManagement.quickNoteShortcut, withAction: {
            self.quickNote(self)
        })
        
        NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged) {
            return $0
        }
        
        NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown) {
            if self.keyDown(with: $0) {
                return $0
            }

            return nil
        }
    }
    
    private func configureDelegates() {
        self.search.vcDelegate = self
        self.search.delegate = self.search
        self.sidebarSplitView.delegate = self
        self.sidebarOutlineView.viewDelegate = self
        
        if #available(macOS 10.14, *) {
            UNUserNotificationCenter.current().delegate = self
        }
    }
    
    // MARK: - Actions

    @IBAction public func openRecentPopup(_ sender: Any) {
        search.searchesMenu = search.generateRecentMenu()
        let general = search.searchesMenu!.item(at: 0)
        search.searchesMenu!.popUp(positioning: general, at: NSPoint(x: 5, y: search.frame.height + 7), in: search)
    }

    @IBAction func searchAndCreate(_ sender: Any) {
        AppDelegate.mainWindowController?.window?.makeKeyAndOrderFront(nil)
        
        guard let vc = ViewController.shared() else { return }

        if let view = NSApplication.shared.mainWindow?.firstResponder as? NSTextView, let textField = view.superview?.superview {

            if textField.isKind(of: SearchTextField.self) {
                if vc.search.searchesMenu != nil {
                    vc.search.searchesMenu = nil
                } else {
                    vc.search.searchesMenu = vc.search.generateRecentMenu()
                    let general = vc.search.searchesMenu!.item(at: 0)
                    vc.search.searchesMenu!.popUp(positioning: general, at: NSPoint(x: 5, y: vc.search.frame.height + 7), in: vc.search)

                    return
                }
            }
        }

        let size = UserDefaultsManagement.horizontalOrientation
            ? vc.splitView.subviews[0].frame.height
            : vc.splitView.subviews[0].frame.width

        if size == 0 {
            toggleNoteList(self)
        }
        
        vc.search.window?.makeFirstResponder(vc.search)
    }

    @IBAction func sortBy(_ sender: NSMenuItem) {
        if let id = sender.identifier {
            let key = String(id.rawValue.dropFirst(3))
            guard let sortBy = SortBy(rawValue: key) else { return }

            if sortBy.rawValue == UserDefaultsManagement.sort.rawValue {
                UserDefaultsManagement.sortDirection = !UserDefaultsManagement.sortDirection
            }

            UserDefaultsManagement.sort = sortBy

            if let submenu = sortByOutlet.submenu {
                for item in submenu.items {
                    item.state = NSControl.StateValue.off
                }
            }
            
            sender.state = NSControl.StateValue.on
            
            ViewController.shared()?.buildSearchQuery()
            ViewController.shared()?.updateTable()
        }
    }
        
    // Ask project password before move to encrypted
    public func moveReq(notes: [Note], project: Project, completion: @escaping (Bool) -> ()) {
        for note in notes {
            if note.isEncrypted() && project.isEncrypted {
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.informativeText = NSLocalizedString("You cannot move an already encrypted note to an encrypted directory. You must first decrypt the note and repeat the steps.", comment: "")
                alert.messageText = NSLocalizedString("Move error", comment: "")
                alert.runModal()
                return
            }
        }
        
        // Encrypted and locked
        if project.isEncrypted && project.isLocked() {
            getMasterPassword() { password in
                self.sidebarOutlineView.unlock(projects: [project], password: password)
                if project.password != nil {
                    self.move(notes: notes, project: project)
                    
                    for note in notes {
                        note.encryptAndUnlock(password: password)
                    }
                    completion(true)
                    return
                }
                
                completion(false)
            }
            return
        }
        
        self.move(notes: notes, project: project)
        
        // Encrypted and non locked
        if project.isEncrypted, let password = project.password {
            for note in notes {
                note.encryptAndUnlock(password: password)
            }
        }
        
        completion(true)
    }
    
    private func move(notes: [Note], project: Project) {
        let selectedRow = notesTableView.selectedRowIndexes.min()
        
        for note in notes {
            if note.project == project {
                continue
            }

            if note.isEncrypted() {
                _ = note.lock()
            }

            let destination = project.url.appendingPathComponent(note.name, isDirectory: false)

            note.moveImages(to: project)
            
            _ = note.move(to: destination, project: project)

            if !storage.searchQuery.isFit(note: note) {
                notesTableView.removeRows(notes: [note])

                if let i = selectedRow, i > -1 {
                    if notesTableView.noteList.count > i {
                        notesTableView.selectRow(i)
                    } else {
                        notesTableView.selectRow(notesTableView.noteList.count - 1)
                    }
                }
            }

            note.invalidateCache()
        }
        
        editor.clear()
    }

    override func viewDidResize() {
        guard let vc = ViewController.shared() else { return }
        vc.checkSidebarConstraint()

        super.viewDidResize()
    }

    func reloadSideBar() {
        guard let outline = sidebarOutlineView else { return }

        sidebarTimer.invalidate()
        sidebarTimer = Timer.scheduledTimer(timeInterval: 1.2, target: outline, selector: #selector(outline.reloadSidebar), userInfo: nil, repeats: false)
    }
        
    func setTableRowHeight() {
        notesTableView.rowHeight = CGFloat(21 + UserDefaultsManagement.cellSpacing)
        notesTableView.reloadData()
    }
            
    public func keyDown(with event: NSEvent) -> Bool {
        guard let mw = MainWindowController.shared() else { return false }

        guard self.alert == nil else {
            if event.keyCode == kVK_Escape, let unwrapped = alert {
                mw.endSheet(unwrapped.window)
                self.alert = nil
            }

            return true
        }

        if event.modifierFlags.contains(.shift)
            && event.modifierFlags.contains(.option)
            && event.keyCode == kVK_ANSI_N {

            sidebarOutlineView.createFolder(NSMenuItem())
            return false
        }

        if event.keyCode == kVK_Delete && event.modifierFlags.contains(.command) && editor.hasFocus() {
            editor.deleteToBeginningOfLine(nil)
            return false
        }
        
        // Return / Cmd + Return navigation
        if event.keyCode == kVK_Return {
            if let fr = NSApp.mainWindow?.firstResponder, self.alert == nil {
                if event.modifierFlags.contains(.command) {
                    if fr.isKind(of: NotesTableView.self) {
                        NSApp.mainWindow?.makeFirstResponder(self.sidebarOutlineView)

                        if sidebarOutlineView.selectedRowIndexes.count == 0 {
                            sidebarOutlineView.selectRowIndexes([0], byExtendingSelection: false)
                        } else {
                            sidebarOutlineView.selectRowIndexes(sidebarOutlineView.selectedRowIndexes, byExtendingSelection: false)
                        }

                        return false
                    }
                    
                    if fr.isKind(of: EditTextView.self) || fr.isKind(of: MPreviewView.self) {
                        NSApp.mainWindow?.makeFirstResponder(self.notesTableView)
                        return false
                    }
                } else {
                    if fr.isKind(of: SidebarOutlineView.self) {
                        self.notesTableView.selectCurrent()
                        NSApp.mainWindow?.makeFirstResponder(self.notesTableView)
                        return false
                    }
                    
                    if let note = editor.note, fr.isKind(of: NotesTableView.self) {
                        if note.container != .encryptedTextPack {
                            if vcEditor?.isPreviewEnabled() == true {
                                disablePreview()
                            }
                            NSApp.mainWindow?.makeFirstResponder(editor)
                        }
                        return false
                    }
                }
            }
            
            return true
        }
        
        // Tab / Control + Tab
        if event.keyCode == kVK_Tab {
            if event.modifierFlags.contains(.control) {
                self.notesTableView.window?.makeFirstResponder(self.notesTableView)
                return true
            }

            if let fr = NSApp.mainWindow?.firstResponder, fr.isKind(of: NotesTableView.self) {
                NSApp.mainWindow?.makeFirstResponder(self.notesTableView)
                return false
            }
        }
                
        // Focus search bar on ESC
        if (
            (
                event.keyCode == kVK_Escape
                || (
                    event.characters == "." &&
                    event.modifierFlags.contains(.command)
                )
            )
            && NSApplication.shared.mainWindow == NSApplication.shared.keyWindow
            && UserDefaultsManagement.shouldFocusSearchOnESCKeyDown
            && !editor.hasMarkedText()
        ) {
            self.view.window?.orderFront(nil)
            self.view.window?.makeKey()
            
            search.searchesMenu = nil

            if NSApplication.shared.mainWindow?.firstResponder === editor, editor.selectedRange().length > 0 {
                editor.selectedRange = NSRange(location: editor.selectedRange().upperBound, length: 0)
                return false
            }

            if let view = NSApplication.shared.mainWindow?.firstResponder as? NSTextView, let textField = view.superview?.superview, textField.isKind(of: NameTextField.self) {
                NSApp.mainWindow?.makeFirstResponder( self.notesTableView)
                return false
            }

            if self.editAreaScroll.isFindBarVisible {
                cancelTextSearch()
                NSApp.mainWindow?.makeFirstResponder(editor)
                return false
            }

            // Renaming is in progress
            if titleLabel.isEditable {
                titleLabel.editModeOff()
                titleLabel.window?.makeFirstResponder(notesTableView)
                return false
            }

            UserDefaultsManagement.lastSidebarItem = nil
            UserDefaultsManagement.lastProjectURL = nil
            UserDefaultsManagement.lastSelectedURL = nil

            notesTableView.scroll(.zero)
            
            let hasSelectedNotes = notesTableView.selectedRow > -1
            let hasSelectedBarItem = sidebarOutlineView.selectedRow > -1
            
            if hasSelectedBarItem && hasSelectedNotes {
                UserDataService.instance.isNotesTableEscape = true
                notesTableView.deselectAll(nil)
                NSApp.mainWindow?.makeFirstResponder(search)
                return false
            }

            sidebarOutlineView.deselectAll(nil)
            sidebarOutlineView.scrollRowToVisible(0)
            cleanSearchAndEditArea()

            return true
        }

        // Search cmd-f
        if (event.characters?.unicodeScalars.first == "f" && event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control)) {
            if self.notesTableView.getSelectedNote() != nil {
                if search.stringValue.count > 0 {
                    let pb = NSPasteboard(name: NSPasteboard.Name.find)
                    pb.declareTypes([.textFinderOptions, .string], owner: nil)
                    pb.setString(search.stringValue, forType: NSPasteboard.PasteboardType.string)
                }

                //Turn off preview mode as text search works only in text editor
                disablePreview()
                return true
            }
        }

        if let fr = mw.firstResponder, !fr.isKind(of: EditTextView.self), !fr.isKind(of: NSTextView.self), !event.modifierFlags.contains(.command),
            !event.modifierFlags.contains(.control) {

            if let char = event.characters {
                let newSet = CharacterSet(charactersIn: char)
                if newSet.isSubset(of: CharacterSet.alphanumerics) {
                    self.search.becomeFirstResponder()
                }
            }
        }

        if event.modifierFlags.contains(.control)
            && !event.modifierFlags.contains(.shift)
            && !event.modifierFlags.contains(.option) {

            switch event.characters?.unicodeScalars.first {
            case "1":
                sidebarOutlineView.selectRowIndexes([0], byExtendingSelection: false)
            case "2":
                sidebarOutlineView.selectRowIndexes([1], byExtendingSelection: false)
            case "3":
                sidebarOutlineView.selectRowIndexes([2], byExtendingSelection: false)
            case "4":
                sidebarOutlineView.selectRowIndexes([3], byExtendingSelection: false)
            case "5":
                sidebarOutlineView.selectRowIndexes([4], byExtendingSelection: false)
            default:
                return true
            }

            return false
        }

        if event.keyCode == kVK_RightArrow {
            if let fr = mw.firstResponder, fr.isKind(of: NotesTableView.self) {
                if let note = vcEditor?.note, note.isEncryptedAndLocked() {
                    unLock(notes: [note])
                    return true
                }
                
                if vcEditor?.isPreviewEnabled() == true {
                    NSApp.mainWindow?.makeFirstResponder(editor.markdownView)
                } else {
                    focusEditArea()
                }

                return false
            }
        }

        if event.keyCode == kVK_LeftArrow {
            if let fr = mw.firstResponder {
                if fr.isKind(of: MPreviewView.self) {
                    sidebarOutlineView.window?.makeFirstResponder(notesTableView)
                    return false
                }

                if fr.isKind(of: NotesTableView.self) {
                    sidebarOutlineView.window?.makeFirstResponder(sidebarOutlineView)

                    if sidebarOutlineView.selectedRowIndexes.count == 0 {
                        sidebarOutlineView.selectRowIndexes([0], byExtendingSelection: false)
                    }

                    return false
                }
            }
        }
        
        return true
    }

    @objc func onWakeNote(note: NSNotification) {
        refillEditArea()
    }

    @IBAction func noteUp(_ sender: NSMenuItem) {
        NSApp.mainWindow?.makeFirstResponder(notesTableView)

        if titleLabel.isEditable {
            titleLabel.editModeOff()
            titleLabel.window?.makeFirstResponder(nil)
        }

        notesTableView.selectPrev()
    }

    @IBAction func noteDown(_ sender: NSMenuItem) {
        NSApp.mainWindow?.makeFirstResponder(notesTableView)

        if titleLabel.isEditable {
            titleLabel.editModeOff()
            titleLabel.window?.makeFirstResponder(nil)
        }

        notesTableView.selectNext()
    }

    @IBAction func sidebarUp(_ sender: NSMenuItem) {
        if titleLabel.isEditable {
            titleLabel.editModeOff()
            titleLabel.window?.makeFirstResponder(nil)
        }

        NSApp.mainWindow?.makeFirstResponder(sidebarOutlineView)

        guard let cgEvent = CGEvent(keyboardEventSource: .none, virtualKey: 126, keyDown: true) else { return }
        cgEvent.flags.remove(.maskShift)
        guard let nsEvent = NSEvent(cgEvent: cgEvent) else { return }
        sidebarOutlineView.keyDown(with: nsEvent)
    }

    @IBAction func sidebarDown(_ sender: NSMenuItem) {
        if titleLabel.isEditable {
            titleLabel.editModeOff()
            titleLabel.window?.makeFirstResponder(nil)
        }

        NSApp.mainWindow?.makeFirstResponder(sidebarOutlineView)

        guard let cgEvent = CGEvent(keyboardEventSource: .none, virtualKey: 125, keyDown: true) else { return }
        cgEvent.flags.remove(.maskShift)
        guard let nsEvent = NSEvent(cgEvent: cgEvent) else { return }
        sidebarOutlineView.keyDown(with: nsEvent)
    }

    @IBAction func makeNote(_ sender: SearchTextField) {
        guard let vc = ViewController.shared() else { return }
        
        if let type = vc.getSidebarType(), type == .Trash {
            vc.sidebarOutlineView.deselectAllRows()
        }

        let value = sender.stringValue
        let inlineTags = vc.sidebarOutlineView.getSelectedInlineTags()

        if (value.count > 0) {
            search.stringValue = String()
            editor.clear()
            var content = String()

            let selectedProject = sidebarOutlineView.getSidebarProjects()?.first ?? Storage.shared().getDefault()

            if UserDefaultsManagement.fileFormat == .Markdown,
                UserDefaultsManagement.naming == .autoRename,
                UserDefaultsManagement.autoInsertHeader,
                UserDefaultsManagement.firstLineAsTitle || selectedProject?.settings.firstLineAsTitle == true {
                content.append("# \(value)\n\n")
            }

            if (inlineTags.count > 0) {
                content.append(inlineTags)
            }

            _ = createNote(name: value, content: content)
        } else {
            _ = createNote(content: inlineTags)
        }
    }
    
    @IBAction func fileMenuNewNote(_ sender: Any) {
        AppDelegate.mainWindowController?.window?.makeKeyAndOrderFront(nil)
        
        guard let vc = ViewController.shared() else { return }
        
        // Disable notes creation if folder encrypted
        if let project = vc.sidebarOutlineView.getSelectedProject(), project.isEncrypted, project.isLocked() {
            let menuItem = NSMenuItem()
            menuItem.identifier = NSUserInterfaceItemIdentifier("menu.newNote")
            vc.toggleFolderLock(menuItem)
            return
        }
        
        if let type = vc.getSidebarType(), type == .Trash {
            vc.sidebarOutlineView.deselectAllRows()
        }

        let inlineTags = vc.sidebarOutlineView.getSelectedInlineTags()

        _ = vc.createNote(content: inlineTags)
    }

    @IBAction func fileMenuNewRTF(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        
        if let type = vc.getSidebarType(), type == .Trash {
            vc.sidebarOutlineView.deselectAllRows()
        }
        
        _ = vc.createNote(type: .RichText)
    }
        
    @IBAction func fileName(_ sender: NSTextField) {
        guard let note = notesTableView.getNoteFromSelectedRow() else { return }

        let value = sender.stringValue
        let url = note.url
        
        let newName = sender.stringValue + "." + note.url.pathExtension
        let isSoftRename = note.url.lastPathComponent.lowercased() == newName.lowercased()
        
        if note.project.fileExist(fileName: value, ext: note.url.pathExtension), !isSoftRename {
            self.alert = NSAlert()
            guard let alert = self.alert else { return }

            let informativeText = NSLocalizedString("Note with name \"%@\" already exists in selected directory.", comment: "")

            alert.alertStyle = .critical
            alert.informativeText = String(format: informativeText, value)
            alert.runModal()
            
            note.parseURL()
            sender.stringValue = note.getTitleWithoutLabel()
            return
        }
        
        guard value.count > 0 else {
            sender.stringValue = note.getTitleWithoutLabel()
            return
        }
        
        sender.isEditable = false
        
        let newUrl = note.getNewURL(name: value)
        UserDataService.instance.focusOnImport = newUrl
        
        if note.url.path == newUrl.path {
            return
        }
        
        note.overwrite(url: newUrl)
        
        do {
            try FileManager.default.moveItem(at: url, to: newUrl)
            print("File moved from \"\(url.deletingPathExtension().lastPathComponent)\" to \"\(newUrl.deletingPathExtension().lastPathComponent)\"")
        } catch {
            note.overwrite(url: url)
        }
    }
            
    @IBAction func makeMenu(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        
        if let type = vc.getSidebarType(), type == .Trash {
            vc.sidebarOutlineView.deselectAllRows()
        }
        
        _ = vc.createNote()
    }
        
    @IBAction func renameMenu(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        vc.titleLabel.restoreResponder = vc.view.window?.firstResponder
        vc.switchTitleToEditMode()
    }
    
    @objc func switchTitleToEditMode() {
        guard let vc = ViewController.shared() else { return }

        if vc.notesTableView.selectedRow > -1 {
            vc.titleLabel.editModeOn()
            vc.titleBarAdditionalView.alphaValue = 0
            
            if let note = vc.editor.note, note.getFileName().isValidUUID {
                vc.titleLabel.stringValue = note.getFileName()
            }

            return
        }

        if let md = AppDelegate.mainWindowController {
            if let actionOnDoubleClick = UserDefaults.standard.object(forKey: "AppleActionOnDoubleClick") as? String {

                switch actionOnDoubleClick {
                case "Maximize":
                    md.maximizeWindow()
                case "Minimize":
                    md.window?.performMiniaturize(nil)
                default:
                    break
                }
            }
        }
    }

    @IBAction func toggleNoteList(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }

        let size = UserDefaultsManagement.horizontalOrientation
            ? vc.splitView.subviews[0].frame.height
            : vc.splitView.subviews[0].frame.width

        if size == 0 {
            var size = UserDefaultsManagement.sidebarSize
            if UserDefaultsManagement.sidebarSize == 0 {
                size = 250
            }

            vc.splitView.shouldHideDivider = false
            vc.splitView.setPosition(size, ofDividerAt: 0)
        } else if vc.splitView.shouldHideDivider {
            vc.splitView.shouldHideDivider = false
            vc.splitView.setPosition(UserDefaultsManagement.sidebarSize, ofDividerAt: 0)
        } else {
            UserDefaultsManagement.sidebarSize = size

            vc.splitView.shouldHideDivider = true
            vc.splitView.setPosition(0, ofDividerAt: 0)

            DispatchQueue.main.async {
                vc.splitView.setPosition(0, ofDividerAt: 0)
            }
        }

        vc.editor.updateTextContainerInset()
    }
    
    @IBAction func toggleSidebar(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }

        if isVisibleSidebar() {
            UserDefaultsManagement.realSidebarSize = Int(vc.sidebarSplitView.subviews[0].frame.width)
            vc.sidebarSplitView.setPosition(0, ofDividerAt: 0)
        } else {
            vc.sidebarSplitView.setPosition(CGFloat(UserDefaultsManagement.realSidebarSize), ofDividerAt: 0)

            vc.reloadSideBar()
        }

        vc.editor.updateTextContainerInset()
    }
    
    @IBAction func emptyTrash(_ sender: NSMenuItem) {
        let notes = storage.getAllTrash()
        for note in notes {
            _ = note.removeFile()
        }
        
        NSSound(named: "Pop")?.play()
    }
        
    @IBAction func lockAll(_ sender: Any) {
        let projects = storage.getProjects().filter({ $0.isEncrypted && !$0.isLocked() })
        sidebarOutlineView.lock(projects: projects)
        
        let editors = AppDelegate.getEditTextViews()
        var unlockedEditors = [EditTextView]()
        
        for editor in editors {
            if let note = editor.note, note.isUnlocked() {
                unlockedEditors.append(editor)
            }
        }
        
        for editor in unlockedEditors {
            editor.lockEncryptedView()
        }
    
        let notes = storage.noteList.filter({ $0.isUnlocked() })
        for note in notes {
            if note.lock() {
                removeTags(note: note)
                notesTableView.reloadRow(note: note)
            }
        }
        
        NSApp.mainWindow?.makeFirstResponder(notesTableView)
    }
        
    @available(macOS 10.14, *)
    public func sendNotification() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.badge,.sound,.alert]) { granted, error in
            if error != nil {
                print("User permission is not granted : \(granted)")
            }
        }

        let content = UNMutableNotificationContent()
        content.title = "Upload over SSH done"
        content.sound = .default
   
        let date = Date().addingTimeInterval(1)
        let dateComponent = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponent, repeats: false)
    
    
        let uuid = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuid, content: content, trigger: trigger)
    
        center.add(request) { error in }
    }
        
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, textField == titleLabel else { return }
        
        if titleLabel.isEditable == true {
            titleLabel.editModeOff()
            fileName(titleLabel)
            view.window?.makeFirstResponder(notesTableView)
        }
        else {
            if let currentNote = notesTableView.getSelectedNote() {
                updateTitle(note: currentNote)
            }
        }
    }
    
    public func reSort(note: Note) {
        if !updateViews.contains(note) {
            updateViews.append(note)
        }

        rowUpdaterTimer.invalidate()
        rowUpdaterTimer = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(updateTableViews), userInfo: nil, repeats: false)
    }

    public func removeForever() {
        guard let vc = ViewController.shared() else { return }
        guard let notes = vc.notesTableView.getSelectedNotes() else { return }
        guard let window = MainWindowController.shared() else { return }

        vc.alert = NSAlert()

        guard let alert = vc.alert else { return }

        alert.messageText = String(format: NSLocalizedString("Are you sure you want to irretrievably delete %d note(s)?", comment: ""), notes.count)

        alert.informativeText = NSLocalizedString("This action cannot be undone.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Remove note(s)", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                let selectedRow = vc.notesTableView.selectedRowIndexes.min()
                vc.editor.clear()
                vc.storage.removeNotes(notes: notes, completely: true) { _ in
                    DispatchQueue.main.async {
                        vc.notesTableView.removeRows(notes: notes)
                        if let i = selectedRow, i > -1 {
                            vc.notesTableView.selectRow(i)
                        }
                    }
                }
            }

            vc.alert = nil
        }
    }
    
    @objc private func updateTableViews() {
        let editors = AppDelegate.getEditTextViews()
        
        notesTableView.beginUpdates()
        for note in updateViews {
            notesTableView.reloadRow(note: note)

            if search.stringValue.count == 0 {
                sortAndMove(note: note)
            }
            
            // Reloading nstextview in multiple windows
            
            for editor in editors {
                if editor.note == note, !editor.isLastEdited, let window = editor.window, !window.isKeyWindow {
                    editor.editorViewController?.refillEditArea(force: true)
                }
            }
        }

        updateViews.removeAll()
        notesTableView.endUpdates()
    }
    
    func getSidebarType() -> SidebarItemType? {
        let sidebarItem = sidebarOutlineView.item(atRow: sidebarOutlineView.selectedRow) as? SidebarItem
        
        if let type = sidebarItem?.type {
            return type
        }
        
        return nil
    }
    
    public func getSidebarItem() -> SidebarItem? {
        if let sidebarItem = sidebarOutlineView.item(atRow: sidebarOutlineView.selectedRow) as? SidebarItem {
            return sidebarItem
        }
        
        return nil
    }

    func updateTable(completion: @escaping () -> Void = {}) {

        let timestamp = Date().toMillis()

        self.search.timestamp = timestamp
        self.searchQueue.cancelAllOperations()

        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self] in
            guard let self = self else {return}

            let projects = Storage.shared().searchQuery.projects
            for project in projects {
                self.preLoadNoteTitles(in: project)
            }

            let source = self.storage.noteList
            var notes = [Note]()

            for note in source {
                if operation.isCancelled {
                    completion()
                    return
                }

                if self.storage.searchQuery.isFit(note: note) {
                    notes.append(note)
                }
            }
            
            let orderedNotesList = self.storage.sortNotes(noteList: notes, operation: operation)

            // Check diff
            if orderedNotesList == self.notesTableView.noteList {
                completion()
                return
            }

            if operation.isCancelled {
                completion()
                return
            }
            
            self.notesTableView.noteList = orderedNotesList
            
            guard self.notesTableView.noteList.count > 0 else {
                DispatchQueue.main.async {
                    self.editor.clear()
                    self.notesTableView.reloadData()
                    completion()
                }
                return
            }

            DispatchQueue.main.async {
                self.notesTableView.reloadData()
                completion()
            }
        }
        
        self.searchQueue.addOperation(operation)
    }

    /*
     Load titles in cases sort by Title
     */
    private func preLoadNoteTitles(in project: Project) {
        if (UserDefaultsManagement.sort == .title || project.settings.sortBy == .title) && project.settings.isFirstLineAsTitle() {
            let notes = storage.noteList.filter({ $0.project == project })
            for note in notes {
                note.loadPreviewInfo()
            }
        }
    }
    
    public func reloadFonts() {
        let webkitPreview = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wkPreview")
        try? FileManager.default.removeItem(at: webkitPreview)

        Storage.shared().resetCacheAttributes()

        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let evc = editor.editorViewController {
                MPreviewView.template = nil
                NotesTextProcessor.resetCaches()
                evc.refillEditArea(force: true)
            }
        }
    }

    public func buildSearchQuery() {
        let searchQuery = SearchQuery()

        var projects = [Project]()
        var tags = [String]()
        var type: SidebarItemType?

        if let sidebarProjects = sidebarOutlineView.getSidebarProjects() {
            projects = sidebarProjects
        }

        if let sidebarTags = sidebarOutlineView.getSidebarTags() {
            tags = sidebarTags
        }

        if let sidebarTableView = self.sidebarOutlineView {
            let indexPaths = sidebarTableView.selectedRowIndexes

            for indexPath in indexPaths {
                if let item = sidebarTableView.item(atRow: indexPath) as? SidebarItem {
                    if item.type == .All ||
                        item.type == .Untagged ||
                        item.type == .Todo ||
                        item.type == .Trash ||
                        item.type == .Inbox {

                        type = item.type
                    }
                }
            }
        }

        if projects.count == 0 && type == nil {
            type = .All
        }

        let filter = search.stringValue

        searchQuery.projects = projects
        searchQuery.tags = tags
        searchQuery.setFilter(filter)

        if let type = type {
            searchQuery.setType(type)
        }

        self.storage.setSearchQuery(value: searchQuery)
    }

    @objc func selectNullTableRow(note: Note) {
        self.selectRowTimer.invalidate()
        self.selectRowTimer = Timer.scheduledTimer(timeInterval: TimeInterval(0.2), target: self, selector: #selector(self.selectRowInstant), userInfo: note, repeats: false)
    }

    @objc private func selectRowInstant(_ timer: Timer) {
        if let note = timer.userInfo as? Note {
            if let i = self.notesTableView.noteList.firstIndex(of: note) {
                notesTableView.selectRowIndexes([i], byExtendingSelection: false)
                notesTableView.scrollRowToVisible(i)
            }
        }
    }
        
    func focusTable() {
        DispatchQueue.main.async {
            let index = self.notesTableView.selectedRow > -1 ? self.notesTableView.selectedRow : 0

            self.notesTableView.window?.makeFirstResponder(self.notesTableView)
            self.notesTableView.selectRowIndexes([index], byExtendingSelection: false)
            self.notesTableView.scrollRowToVisible(index)
        }
    }
    
    func cleanSearchAndEditArea(shouldBecomeFirstResponder: Bool = true, completion: (() -> ())? = nil) {
        search.stringValue = ""
        search.lastSearchQuery = ""

        if shouldBecomeFirstResponder {
            search.becomeFirstResponder()
        }

        notesTableView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
        editor.clear()

        self.buildSearchQuery()
        self.updateTable() {
            DispatchQueue.main.async {
                if shouldBecomeFirstResponder {
                    self.sidebarOutlineView.reloadTags()
                }

                if let completion = completion {
                    completion()
                    return
                }
            }
        }
    }
    
    func makeNoteShortcut() {
        let clipboard = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string)
        if (clipboard != nil) {
            let project = Storage.shared().getMainProject()
            _ = createNote(content: clipboard!, project: project)
            
            let notification = NSUserNotification()
            notification.title = "FSNotes"
            notification.informativeText = "Clipboard successfully saved"
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
    
    func searchShortcut() {
        guard let mainWindow = MainWindowController.shared() else { return }

        if (
            NSApplication.shared.isActive
            && !NSApplication.shared.isHidden
            && !mainWindow.isMiniaturized
        ) {
            NSApplication.shared.hide(nil)
            return
        }

        UserDefaultsManagement.lastScreenX = nil
        UserDefaultsManagement.lastScreenY = nil

        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(self)
        
        guard let controller = mainWindow.contentViewController as? ViewController
            else { return }
        
        mainWindow.makeFirstResponder(controller.search)
    }
    
    func moveNoteToTop(note index: Int) {
        DispatchQueue.main.async {
            let isPinned = self.notesTableView.noteList[index].isPinned
            let position = isPinned ? 0 : self.notesTableView.countVisiblePinned()
            let note = self.notesTableView.noteList.remove(at: index)

            self.notesTableView.noteList.insert(note, at: position)

            self.notesTableView.reloadRow(note: note)
            self.notesTableView.moveRow(at: index, to: position)
            self.notesTableView.scrollRowToVisible(0)
        }
    }
    
    public func sortAndMove(note: Note, project: Project? = nil) {
        guard let srcIndex = notesTableView.noteList.firstIndex(of: note) else { return }
        let notes = notesTableView.noteList

        let resorted = storage.sortNotes(noteList: notes)
        guard let dstIndex = resorted.firstIndex(of: note) else { return }

        if srcIndex != dstIndex {
            notesTableView.moveRow(at: srcIndex, to: dstIndex)
            notesTableView.noteList = resorted
        }
    }
    
    func pin(selectedNotes: [Note]) {
        if selectedNotes.count == 0 {
            return
        }

        var state = notesTableView.noteList
        var updatedNotes = [(Int, Note)]()
        
        for selectedNote in selectedNotes {
            guard let atRow = notesTableView.getIndex(selectedNote),
                  let rowView = notesTableView.rowView(atRow: atRow, makeIfNecessary: false) as? NoteRowView,
                  let cell = rowView.view(atColumn: 0) as? NoteCellView else { continue }
            
            updatedNotes.append((atRow, selectedNote))
            selectedNote.togglePin()
            cell.renderPin()
        }

        let resorted = storage.sortNotes(noteList: notesTableView.noteList)

        notesTableView.beginUpdates()
        let nowPinned = updatedNotes.filter { _, note in note.isPinned }
        for (row, note) in nowPinned {
            guard let newRow = resorted.firstIndex(where: { $0 === note }) else { continue }
            notesTableView.moveRow(at: row, to: newRow)
            let toMove = state.remove(at: row)
            state.insert(toMove, at: newRow)
        }

        let nowUnpinned = updatedNotes
            .filter({ (_, note) -> Bool in !note.isPinned })
            .compactMap({ (_, note) -> (Int, Note)? in
                guard let curRow = state.firstIndex(where: { $0 === note }) else { return nil }
                return (curRow, note)
            })
        for (row, note) in nowUnpinned.reversed() {
            guard let newRow = resorted.firstIndex(where: { $0 === note }) else { continue }
            notesTableView.moveRow(at: row, to: newRow)
            let toMove = state.remove(at: row)
            state.insert(toMove, at: newRow)
        }

        notesTableView.noteList = resorted
        notesTableView.endUpdates()
        
        //notesTableView.reloadData()
        //notesTableView.selectRowIndexes(newIndexes, byExtendingSelection: false)
    }

    func external(selectedNotes: [Note]) {
        if selectedNotes.count == 0 {
            return
        }
        
        for note in selectedNotes {
            var path = note.url.path
            if note.isTextBundle() && !note.isUnlocked(), let url = note.getContentFileURL() {
                path = url.path
            }

            NSWorkspace.shared.openFile(path, withApplication: UserDefaultsManagement.externalEditor)
        }
    }
    
    private func loadBookmarks(data: Data?) {
        if let accessData = data,
            let bookmarks = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSURL.self, NSData.self], from: accessData) as? [URL: Data] {

            for bookmark in bookmarks {
                var isStale = false
                
                do {
                    let url = try URL.init(resolvingBookmarkData: bookmark.value, options: NSURL.BookmarkResolutionOptions.withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                    
                    if !url.startAccessingSecurityScopedResource() {
                        print("RSA key not available: \(url.path)")
                    } else {
                        print("Access for RSA key is successfull restored \(url)")
                    }
                } catch {
                    print("Error restoring sftp bookmark: \(error)")
                }
            }
        }
    }
    
    func loadMoveMenu() {
        guard let vc = ViewController.shared(), let note = vc.notesTableView.getSelectedNote() else { return }
        
        let moveTitle = NSLocalizedString("Move", comment: "Menu")
        if let prevMenu = noteMenu.item(withTitle: moveTitle) {
            noteMenu.removeItem(prevMenu)
        }
        
        let moveMenuItem = NSMenuItem()
        moveMenuItem.title = NSLocalizedString("Move", comment: "Menu")
        
        noteMenu.addItem(moveMenuItem)
        let moveMenu = NSMenu()

        if UserDefaultsManagement.inlineTags, let tagsMenu = noteMenu.item(withTitle: NSLocalizedString("Tags", comment: "")) {
            noteMenu.removeItem(tagsMenu)
        }
        
        if !note.isTrash() {
            let trashMenu = NSMenuItem()
            trashMenu.title = NSLocalizedString("Trash", comment: "Sidebar label")
            trashMenu.action = #selector(vc.deleteNote(_:))
            trashMenu.tag = 555
            moveMenu.addItem(trashMenu)
            moveMenu.addItem(NSMenuItem.separator())
        }
                
        let projects = storage.getSortedProjects()
        for item in projects {
            if note.project == item || item.isTrash {
                continue
            }
            
            let menuItem = NSMenuItem()
            menuItem.title = item.getNestedLabel()
            menuItem.representedObject = item
            menuItem.action = #selector(vc.moveNote(_:))
            moveMenu.addItem(menuItem)
        }

        noteMenu.setSubmenu(moveMenu, for: moveMenuItem)
        loadHistory()
    }
    
    public func loadHistory() {
        guard let vc = ViewController.shared(),
            let notes = vc.notesTableView.getSelectedNotes(),
            let note = notes.first
        else { return }

        let title = NSLocalizedString("History", comment: "")
        let historyMenu = noteMenu.item(withTitle: title)
        historyMenu?.submenu?.removeAllItems()
        historyMenu?.isEnabled = false
        historyMenu?.isHidden = !note.project.hasCommitsDiffsCache()

        guard notes.count == 0x01 else { return }

        DispatchQueue.global().async {
            let commits = note.getCommits()

            DispatchQueue.main.async {
                guard commits.count > 0 else {
                    historyMenu?.isEnabled = false
                    return
                }
                
                for commit in commits {
                    let menuItem = NSMenuItem()
                    menuItem.title = commit.getDate()
                    menuItem.representedObject = commit
                    menuItem.action = #selector(vc.checkoutRevision(_:))
                    historyMenu?.submenu?.addItem(menuItem)
                }
                
                historyMenu?.isEnabled = true
            }
        }
    }

    func loadSortBySetting() {
        let viewLabel = NSLocalizedString("View", comment: "Menu")
        let sortByLabel = NSLocalizedString("Sort by", comment: "View menu")

        guard
            let menu = NSApp.menu,
            let view = menu.item(withTitle: viewLabel),
            let submenu = view.submenu,
            let sortMenu = submenu.item(withTitle: sortByLabel),
            let sortItems = sortMenu.submenu else {
            return
        }
        
        let sort = UserDefaultsManagement.sort
        
        for item in sortItems.items {
            if let id = item.identifier, id.rawValue ==  "SB.\(sort.rawValue)" {
                item.state = NSControl.StateValue.on
            }
        }
    }
    
    func registerKeyValueObserver() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(ubiquitousKeyValueStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default)

        if NSUbiquitousKeyValueStore.default.synchronize() == false {
            fatalError("This app was not built with the proper entitlement requests.")
        }
        
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    @objc func ubiquitousKeyValueStoreDidChange(_ notification: NSNotification) {
        if let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            for key in keys {
                if key == "co.fluder.fsnotes.pins.shared" {
                    let changedNotes = storage.getUpdatedPins()
                    
                    DispatchQueue.main.async {
                        ViewController.shared()?.pin(selectedNotes: changedNotes)
                    }
                }
                
                if key.startsWith(string: "es.fsnot.project-settings") {
                    let settingsKey = key.replacingOccurrences(of: "es.fsnot.project-settings", with: "")
                    if let project = storage.getProjectBy(settingsKey: settingsKey) {
                        project.reloadSettings()
                    }
                }
            }
        }
    }
    
    func checkSidebarConstraint() {
        if sidebarSplitView.subviews[0].frame.width > 50 {
            searchTopConstraint.constant = 8
            return
        }
        
        if UserDefaultsManagement.hideRealSidebar || sidebarSplitView.subviews[0].frame.width < 50 {
            
            searchTopConstraint.constant = CGFloat(25)
            return
        }
        
        searchTopConstraint.constant = 8
    }
        
    @IBAction func sidebarItemVisibility(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        let isChecked = sender.state == .on

        switch sender.tag {
            case 1:
                UserDefaultsManagement.sidebarVisibilityInbox = isChecked
            case 2:
                UserDefaultsManagement.sidebarVisibilityNotes = isChecked
            case 3:
                UserDefaultsManagement.sidebarVisibilityTodo = isChecked
            case 5:
                UserDefaultsManagement.sidebarVisibilityTrash = isChecked
            case 6:
                UserDefaultsManagement.sidebarVisibilityUntagged = isChecked
            default:
                break
        }

        ViewController.shared()?.sidebarOutlineView.reloadSidebar()
    }

    @IBAction func textFinder(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }

        if !vc.editAreaScroll.isFindBarVisible, [NSFindPanelAction.next.rawValue, NSFindPanelAction.previous.rawValue].contains(UInt(sender.tag)) {

            if vcEditor?.isPreviewEnabled() == true && vc.notesTableView.selectedRow > -1 {
                vc.disablePreview()
            }

            let menu = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            menu.tag = NSTextFinder.Action.showFindInterface.rawValue
            vc.editor.performTextFinderAction(menu)
        }

        vc.editor.performTextFinderAction(sender)
    }

    @IBAction func prevHistory(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }

        if vc.notesTableView.historyPosition > 0 {
            let prev = vc.notesTableView.historyPosition - 1
            let prevUrl = vc.notesTableView.history[prev]

            if let note = Storage.shared().getBy(url: prevUrl) {
                vc.notesTableView.saveNavigationHistory(note: note)
                vc.cleanSearchAndEditArea(completion: { () -> Void in
                    vc.notesTableView.selectRowAndSidebarItem(note: note)
                })
            }

            vc.notesTableView.historyPosition = prev
        }
    }

    @IBAction func nextHistory(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }

        if vc.notesTableView.historyPosition < vc.notesTableView.history.count - 1 {
            let next = vc.notesTableView.historyPosition + 1
            let nextUrl = vc.notesTableView.history[next]

            if let note = Storage.shared().getBy(url: nextUrl) {
                vc.cleanSearchAndEditArea(completion: { () -> Void in
                    vc.notesTableView.selectRowAndSidebarItem(note: note)
                })
            }

            vc.notesTableView.historyPosition = next
        }
    }

    func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        for item in menu.items {
            if item.title == NSLocalizedString("Copy Link", comment: "")  {
                item.action = #selector(NSText.copy(_:))
            }
                        
            if item.title == NSLocalizedString("Font", comment: "")
                || item.title == "Make Link"
                || item.title == NSLocalizedString("Make Link", comment: "") {
                menu.removeItem(item)
            }
        }

        return menu
    }

    func splitViewWillResizeSubviews(_ notification: Notification) {
        editor.updateTextContainerInset()
    }

    public static func shared() -> ViewController? {
        return AppDelegate.mainWindowController?.window?.contentViewController as? ViewController
    }

    public func copy(project: Project, url: URL) -> URL {
        let fileName = url.lastPathComponent
        let destination = project.url.appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: url, to: destination)
            return destination
        } catch {
            let dst = NameHelper.generateCopy(file: url, dstDir: project.url)
            try? FileManager.default.copyItem(at: url, to: dst)
            return dst
        }
    }

    @objc func onSleepNote(note: NSNotification) {
        if UserDefaultsManagement.lockOnSleep {
            lockAll(self)
        }
    }

    @objc func onScreenLocked(note: NSNotification) {
        if UserDefaultsManagement.lockOnScreenActivated{
            lockAll(self)
        }
    }
    
    @objc func onAccentColorChanged(note: NSNotification) {
        sidebarOutlineView.reloadSidebar()
    }

    @objc func onUserSwitch(note: NSNotification) {
        if UserDefaultsManagement.lockOnUserSwitch {
            lockAll(self)
        }
    }

    override func restoreUserActivityState(_ userActivity: NSUserActivity) {
        guard let name = userActivity.userInfo?["note-file-name"] as? String,
            let state = userActivity.userInfo?["state"] as? String,
            let note = Storage.shared().getBy(name: name)
        else { return }

        vcEditor?.changePreviewState(state == "preview")
        
        note.previewState = state == "preview"

        notesTableView.selectRowAndSidebarItem(note: note)
    }

    /*
     Needs update UserActivity if selection did change
     */
    func textViewDidChangeSelection(_ notification: Notification) {
        editor.userActivity?.needsSave = true
    }

    @objc func doubleClickOnNotesTable() {
        let selected = notesTableView.clickedRow

        if (selected < 0) {
            return
        }

        if (notesTableView.noteList.indices.contains(selected)) {
            let currentNote = notesTableView.noteList[selected]
            openInNewWindow(note: currentNote)
        }
    }
    
    public func restoreOpenedWindows() {
        guard let documentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let projectsDataUrl = documentDir.appendingPathComponent("editors.settings")
        
        guard let data = try? Data(contentsOf: projectsDataUrl) else { return }
        guard let unarchivedData = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSDictionary.self, NSString.self, NSData.self, NSNumber.self, NSURL.self], from: data) as? [[String: Any]] else { return }

        var mainKey = false
        for item in unarchivedData.reversed() {
            guard let url = item["url"] as? URL,
                  let frameData = item["frame"] as? Data,
                  let main = item["main"] as? Bool,
                  let isKeyWindow = item["key"] as? Bool,
                  let preview = item["preview"] as? Bool,
                  let note = self.storage.getBy(url: url)
            else { continue }
            
            if main {
                if isKeyWindow {
                    mainKey = true
                }
                
                editor.changePreviewState(preview)
                
                if let i = self.notesTableView.getIndex(note) {
                    note.previewState = self.editor.isPreviewEnabled()
                    
                    self.notesTableView.saveNavigationHistory(note: note)
                    self.notesTableView.selectRow(i)
                    self.notesTableView.scrollRowToVisible(i)

                    self.editor.window?.makeFirstResponder(self.editor)
                }
            } else {
                guard let frame = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: frameData)?.rectValue else { continue }

                self.openInNewWindow(note: note, frame: frame, preview: preview)
           }
        }
        
        if mainKey {
            NSApp.activate(ignoringOtherApps: true)
            self.view.window?.makeKeyAndOrderFront(self)
        }
    }
    
    // Important call after initial updateTable
    
    public func importAndCreate() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {

            // fsnotes://find

            if let url = appDelegate.url {
                appDelegate.url = nil
                appDelegate.search(url: url)
                return
            }

            // Open files in the app

            if let urls = appDelegate.urls {
                appDelegate.importNotes(urls: urls)
                return
            }

            // fsnotes://new/?title=URI-title&txt=URI-content

            let name = appDelegate.newName
            let content = appDelegate.newContent

            if nil != name || nil != content {
                appDelegate.create(name: name ?? "", content: content ?? "")
            }
        }
    }
    
    public func isVisibleNoteList() -> Bool {
        guard let vc = ViewController.shared() else { return false }

        let size = UserDefaultsManagement.horizontalOrientation
            ? vc.splitView.subviews[0].frame.height
            : vc.splitView.subviews[0].frame.width
        
        return size != 0
    }
    
    public func isVisibleSidebar() -> Bool {
        guard let vc = ViewController.shared() else { return false }

        let size = Int(vc.sidebarSplitView.subviews[0].frame.width)
        
        return size != 0
    }

    private func cacheGitRepositories() {
        _ = Storage.shared().getProjects().filter({ $0.hasRepository() }).map({
            $0.cacheHistory()
        })
    }
}
