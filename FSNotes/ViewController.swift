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
import WebKit
import LocalAuthentication
import Foundation

class ViewController: NSViewController,
    NSTextViewDelegate,
    NSTextFieldDelegate,
    NSSplitViewDelegate,
    NSOutlineViewDelegate,
    NSOutlineViewDataSource,
    WebFrameLoadDelegate,
    NSMenuItemValidation {
    // MARK: - Properties
    public var fsManager: FileSystemEventManager?
    public var projectSettingsViewController: ProjectSettingsViewController?

    let storage = Storage.sharedInstance()
    var alert: NSAlert?
    var noteLoading: ProgressState = .none
    var timer = Timer()
    var sidebarTimer = Timer()
    var previewResizeTimer = Timer()
    var rowUpdaterTimer = Timer()
    let searchQueue = OperationQueue()
    var printWebView = WebView()
    var tagsScannerQueue = [Note]()

    /* Git */
    public var snapshotsTimer = Timer()
    public var lastSnapshot: Int = 0
    public var isGitProcessLocked = false

    private var updateViews = [Note]()

    public var breakUndoTimer = Timer()

    override var representedObject: Any? {
        didSet { }  // Update the view, if already loaded.
    }

    public var currentPreviewState: PreviewState = UserDefaultsManagement.preview ? .on : .off

    // MARK: - IBOutlets
    @IBOutlet var emptyEditAreaImage: NSImageView!
    @IBOutlet weak var splitView: EditorSplitView!
    @IBOutlet var editArea: EditTextView!
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
    @IBOutlet weak var newNoteTopConstraint: NSLayoutConstraint!

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
            previewButton.state = currentPreviewState == .on ? .on : .off
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
                    
                    if let note = EditTextView.note {
                        if note.isUnlocked() {
                            self?.lockUnlock.image = NSImage(named: NSImage.lockUnlockedTemplateName)
                        } else {
                            self?.lockUnlock.image = NSImage(named: NSImage.lockLockedTemplateName)
                        }
                    }

                    self?.lockUnlock.isHidden = (EditTextView.note == nil)

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
        DispatchQueue.global().async {
            self.storage.loadAllTagsOnly()

            DispatchQueue.main.async {
                self.reloadSideBar()
            }
        }

        newNoteButton.image =
            NSImage(imageLiteralResourceName: "new_note_button")
                .resize(to: CGSize(width: 30, height: 30))

        //newNoteButton.setButtonType(.momentaryLight)

        scheduleSnapshots()
        configureShortcuts()
        configureDelegates()
        configureLayout()
        configureSidebarAndNotesList()
        configureEditor()

        fsManager = FileSystemEventManager(storage: storage, delegate: self)
        fsManager?.start()

        configureTranslation()
        loadMoveMenu()
        loadSortBySetting()
        checkSidebarConstraint()
        
        #if CLOUDKIT
            self.registerKeyValueObserver()
        #endif
        
        searchQueue.maxConcurrentOperationCount = 1
        notesTableView.doubleAction = #selector(self.doubleClickOnNotesTable)
    }

    override func viewDidAppear() {
        // Restore window position

        if sidebarOutlineView.isFirstLaunch, let x = UserDefaultsManagement.lastScreenX, let y = UserDefaultsManagement.lastScreenY {
            view.window?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        if UserDefaultsManagement.fullScreen {
            view.window?.toggleFullScreen(nil)
        }

        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            if let url = appDelegate.searchQuery {
                appDelegate.searchQuery = nil
                appDelegate.search(url: url)
                return
            }

            if let urls = appDelegate.urls {
                appDelegate.importNotes(urls: urls)
                return
            }

            if nil != appDelegate.newName || nil != appDelegate.newContent {
                let name = appDelegate.newName ?? ""
                let content = appDelegate.newContent ?? ""
                
                appDelegate.create(name: name, content: content)
            }
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let vc = ViewController.shared() else { return false}
        
        if let title = menuItem.menu?.identifier?.rawValue {
            switch title {
            case "fsnotesMenu":
                if menuItem.identifier?.rawValue == "emptyTrashMenu" {
                    menuItem.keyEquivalentModifierMask = UserDefaultsManagement.focusInEditorOnNoteSelect
                            ? [.command, .option, .shift]
                            : [.command, .shift]
                    return true
                }
            case "fileMenu":

                if vc.notesTableView.selectedRowIndexes.count > 1,
                   let id = menuItem.identifier?.rawValue, vc.notesTableView.limitedActionsList.contains(id) {

                    return false
                }

                if menuItem.identifier?.rawValue == "fileMenu.removeEncryption",
                   let note = EditTextView.note,
                   !note.isEncrypted()
                {
                    return false
                }

                if menuItem.identifier?.rawValue == "fileMenu.delete" {
                    menuItem.keyEquivalentModifierMask =
                        UserDefaultsManagement.focusInEditorOnNoteSelect
                        ? [.command, .option]
                        : [.command]
                }

                if menuItem.identifier?.rawValue ==  "fileMenu.changeCreationDate" {
                    menuItem.title = NSLocalizedString("Change creation date", comment: "Menu")
                }

                if menuItem.identifier?.rawValue == "fileMenu.tags" {
                    if UserDefaultsManagement.inlineTags {
                        menuItem.isHidden = true
                        return false
                    } else {
                        menuItem.isHidden = false
                    }
                }

                if menuItem.identifier?.rawValue == "fileMenu.history" {
                    if vc.notesTableView.selectedRowIndexes.count > 1 {
                        return false
                    }

                    if EditTextView.note != nil {
                        return true
                    }
                }

                if menuItem.identifier?.rawValue == "fileMenu.togglePin" {
                    if vc.notesTableView.selectedRowIndexes.count < 1 {
                        return false
                    }

                    if EditTextView.note != nil {
                        return true
                    }
                }

                if ["fileMenu.new",
                    "fileMenu.newRtf",
                    "fileMenu.searchAndCreate",
                    "fileMenu.import"
                   ].contains(menuItem.identifier?.rawValue)
                {
                    return true
                }
                
                if vc.notesTableView.selectedRow == -1 {
                    return false
                }

                break
            case "folderMenu":
                if ["folderMenu.attachStorage"].contains(menuItem.identifier?.rawValue) {
                    return true
                }
                
                guard let p = vc.getSidebarProject(), !p.isTrash else {
                    return false
                }
            case "findMenu":
                if ["findMenu.find",
                    "findMenu.findAndReplace",
                    "findMenu.next",
                    "findMenu.prev"
                ].contains(menuItem.identifier?.rawValue), vc.notesTableView.selectedRow > -1 {
                    return true
                }

                return vc.editAreaScroll.isFindBarVisible || vc.editArea.hasFocus()
            case "showInSidebar":
                switch menuItem.tag {
                case 1:
                    menuItem.state = UserDefaultsManagement.sidebarVisibilityInbox ? .on : .off
                case 2:
                    menuItem.state = UserDefaultsManagement.sidebarVisibilityNotes ? .on : .off
                case 3:
                    menuItem.state = UserDefaultsManagement.sidebarVisibilityTodo ? .on : .off
                case 4:
                    menuItem.state = UserDefaultsManagement.sidebarVisibilityArchive ? .on : .off
                case 5:
                    menuItem.state = UserDefaultsManagement.sidebarVisibilityTrash ? .on : .off
                case 6:
                    menuItem.state =     UserDefaultsManagement.sidebarVisibilityUntagged ? .on : .off
                default:
                    break
                }
            case "viewMenu":
                if (menuItem.identifier?.rawValue == "viewMenu.historyBack" &&  vc.notesTableView.historyPosition == 0) {
                    return false
                }

                if (menuItem.identifier?.rawValue == "viewMenu.historyForward" && vc.notesTableView.historyPosition == vc.notesTableView.history.count - 1) {
                    return false
                }
            default:
                break
            }
        }
        
        return true
    }
    
    // MARK: - Initial configuration
    
    private func configureLayout() {
        dropTitle()

        DispatchQueue.main.async {
            self.editArea.updateTextContainerInset()
        }

        notesTableView.setDraggingSourceOperationMask(.every, forLocal: false)

        editArea.textContainerInset.height = 10
        editArea.isEditable = false

        editArea.layoutManager?.allowsNonContiguousLayout = UserDefaultsManagement.nonContiguousLayout

        if #available(OSX 10.13, *) {} else {
            self.editArea.backgroundColor = UserDefaultsManagement.bgColor
        }

        self.editArea.layoutManager?.defaultAttachmentScaling = .scaleProportionallyDown
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        self.editArea.defaultParagraphStyle = paragraphStyle
        self.editArea.typingAttributes[.paragraphStyle] = paragraphStyle
        
        self.editArea.font = UserDefaultsManagement.noteFont
                
        if (UserDefaultsManagement.horizontalOrientation) {
            self.splitView.isVertical = false
        }
        
        self.shareButton.sendAction(on: .leftMouseDown)
        self.setTableRowHeight()
        self.sidebarOutlineView.sidebarItems = Sidebar().getList()

        sidebarOutlineView.selectionHighlightStyle = .regular

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
    }

    private func configureSidebarAndNotesList() {

        // When opened via fsnotes:// scheme – skip (use viewDidAppear)
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate, appDelegate.searchQuery != nil {
            return
        }

        DispatchQueue.main.async {
            self.configureSidebar()

            if UserDefaultsManagement.lastSidebarItem != nil || UserDefaultsManagement.lastProjectURL != nil {
                if let lastSidebarItem = UserDefaultsManagement.lastSidebarItem {
                    let sidebarItem = self.sidebarOutlineView.sidebarItems?.first(where: { ($0 as? SidebarItem)?.type.rawValue == lastSidebarItem })

                    let index = self.sidebarOutlineView.row(forItem: sidebarItem)
                    self.sidebarOutlineView.selectRowIndexes([index], byExtendingSelection: false)
                } else if let lastURL = UserDefaultsManagement.lastProjectURL,
                    let project = self.storage.getProjectBy(url: lastURL) {

                    let items = self.sidebarOutlineView.row(forItem: project)
                    self.sidebarOutlineView.selectRowIndexes([items], byExtendingSelection: false)
                }
                
                return
            }

            self.updateTable() {
                if UserDefaultsManagement.copyWelcome {
                    DispatchQueue.main.async {
                        self.sidebarOutlineView.expandItem(self.storage.getRootProject())
                        let welcome = self.storage.getProjects().first(where: { $0.label == "Welcome" })
                        let index = self.sidebarOutlineView.row(forItem: welcome)
                        self.sidebarOutlineView.selectRowIndexes([index], byExtendingSelection: false)
                    }

                    UserDefaultsManagement.copyWelcome = false
                    return
                }

                if let url = UserDefaultsManagement.lastSelectedURL,
                    let lastNote = self.storage.getBy(url: url),
                    let i = self.notesTableView.getIndex(lastNote) {

                    self.notesTableView.saveNavigationHistory(note: lastNote)
                    self.notesTableView.selectRow(i)
                    self.notesTableView.scrollRowToVisible(i)
                }
            }
        }
    }

    private func configureSidebar() {
        self.storage.restoreProjectsExpandState()
        for project in self.storage.getProjects() {
            if project.isExpanded {
                self.sidebarOutlineView.expandItem(project)
            }
        }
    }
    
    private func configureEditor() {
        self.editArea.isGrammarCheckingEnabled = UserDefaultsManagement.grammarChecking
        self.editArea.isContinuousSpellCheckingEnabled = UserDefaultsManagement.continuousSpellChecking
        self.editArea.smartInsertDeleteEnabled = UserDefaultsManagement.smartInsertDelete
        self.editArea.isAutomaticSpellingCorrectionEnabled = UserDefaultsManagement.automaticSpellingCorrection
        self.editArea.isAutomaticQuoteSubstitutionEnabled = UserDefaultsManagement.automaticQuoteSubstitution
        self.editArea.isAutomaticDataDetectionEnabled = UserDefaultsManagement.automaticDataDetection
        self.editArea.isAutomaticLinkDetectionEnabled = UserDefaultsManagement.automaticLinkDetection
        self.editArea.isAutomaticTextReplacementEnabled = UserDefaultsManagement.automaticTextReplacement
        self.editArea.isAutomaticDashSubstitutionEnabled = UserDefaultsManagement.automaticDashSubstitution

        if UserDefaultsManagement.appearanceType != AppearanceType.Custom {
            if #available(OSX 10.13, *) {
                self.editArea?.linkTextAttributes = [
                    .foregroundColor:  NSColor.init(named: "link")!
                ]
            }
        }

        self.editArea.usesFindBar = true
        self.editArea.isIncrementalSearchingEnabled = true

        self.editArea.textStorage?.delegate = self.editArea.textStorage
        self.editArea.viewDelegate = self
    }

    private func configureShortcuts() {
        MASShortcutMonitor.shared().register(UserDefaultsManagement.newNoteShortcut, withAction: {
            self.makeNoteShortcut()
        })
        
        MASShortcutMonitor.shared().register(UserDefaultsManagement.searchNoteShortcut, withAction: {
            self.searchShortcut()
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
        self.editArea.delegate = self
        self.search.vcDelegate = self
        self.search.delegate = self.search
        self.sidebarSplitView.delegate = self
        self.sidebarOutlineView.viewDelegate = self
    }
    
    // MARK: - Actions

    @IBAction public func openRecentPopup(_ sender: Any) {
        search.searchesMenu = search.generateRecentMenu()
        let general = search.searchesMenu!.item(at: 0)
        search.searchesMenu!.popUp(positioning: general, at: NSPoint(x: 5, y: search.frame.height + 7), in: search)
    }

    @IBAction func searchAndCreate(_ sender: Any) {
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

            UserDefaultsManagement.sort = sortBy
            UserDefaultsManagement.sortDirection = !UserDefaultsManagement.sortDirection
            
            if let submenu = sortByOutlet.submenu {
                for item in submenu.items {
                    item.state = NSControl.StateValue.off
                }
            }
            
            sender.state = NSControl.StateValue.on
            
            guard let controller = ViewController.shared() else { return }

            var sidebarItem: SidebarItem? = nil
            let projects = controller.sidebarOutlineView.getSidebarProjects()
            let tags = controller.sidebarOutlineView.getSidebarTags()

            if projects == nil && tags == nil {
                sidebarItem = controller.getSidebarItem()
            }

            controller.updateTable(search: true, searchText: controller.search.stringValue, sidebarItem: sidebarItem, projects: projects, tags: tags)
        }
    }
    
    @objc func moveNote(_ sender: NSMenuItem) {
        let project = sender.representedObject as! Project
        
        guard let notes = notesTableView.getSelectedNotes() else {
            return
        }
        
        move(notes: notes, project: project)
    }
    
    public func move(notes: [Note], project: Project) {
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

            if !isFit(note: note, shouldLoadMain: true) {
                notesTableView.removeByNotes(notes: [note])

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
        
        editArea.clear()
    }

    func viewDidResize() {
        guard let vc = ViewController.shared() else { return }
        vc.checkSidebarConstraint()

        guard currentPreviewState == .on else { return }

        if noteLoading != .incomplete {
            previewResizeTimer.invalidate()
            previewResizeTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(reloadPreview), userInfo: nil, repeats: false)
        }
    }

    @objc private func reloadPreview() {
        DispatchQueue.main.async {
            MPreviewView.template = nil
            self.refillEditArea(force: true)
        }
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
    
    func refillEditArea(saveTyping: Bool = false, force: Bool = false) {
        noteLoading = .incomplete
        previewButton.state = self.currentPreviewState == .on ? .on : .off

        let selected = notesTableView.selectedRow
        if (selected > -1 && notesTableView.noteList.indices.contains(selected)) {
            if let note = notesTableView.getSelectedNote() {
                editArea.fill(note: note, saveTyping: saveTyping, force: force)
            }
        }

        noteLoading = .done
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

        if event.keyCode == kVK_Delete && event.modifierFlags.contains(.command) && editArea.hasFocus() {
            editArea.deleteToBeginningOfLine(nil)
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
                    
                    if let note = EditTextView.note, fr.isKind(of: NotesTableView.self) {
                        if note.container != .encryptedTextPack {
                            if currentPreviewState == .on {
                                disablePreview()
                            }
                            NSApp.mainWindow?.makeFirstResponder(editArea)
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
        ) {
            search.searchesMenu = nil

            if NSApplication.shared.mainWindow?.firstResponder === editArea, editArea.selectedRange().length > 0 {
                editArea.selectedRange = NSRange(location: editArea.selectedRange().upperBound, length: 0)
                return false
            }

            if let view = NSApplication.shared.mainWindow?.firstResponder as? NSTextView, let textField = view.superview?.superview, textField.isKind(of: NameTextField.self) {
                NSApp.mainWindow?.makeFirstResponder( self.notesTableView)
                return false
            }

            if self.editAreaScroll.isFindBarVisible {
                cancelTextSearch()
                NSApp.mainWindow?.makeFirstResponder(editArea)
                return false
            }

            // Renaming is in progress
            if titleLabel.isEditable {
                titleLabel.editModeOff()
                titleLabel.window?.makeFirstResponder(notesTableView)
                return false
            }

            restoreCurrentPreviewState()

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
                sidebarOutlineView.selectSidebar(type: .All)
            case "2":
                sidebarOutlineView.selectSidebar(type: .Todo)
            case "3":
                sidebarOutlineView.selectSidebar(type: .Archive)
            case "4":
                sidebarOutlineView.selectSidebar(type: .Trash)
            case "5":
                sidebarOutlineView.selectSidebarRoot()
            default:
                return true
            }

            return false
        }

        if event.keyCode == kVK_RightArrow {
            if let fr = mw.firstResponder, fr.isKind(of: NotesTableView.self) {
                if currentPreviewState == .on {
                    NSApp.mainWindow?.makeFirstResponder(editArea.markdownView)
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

    func cancelTextSearch() {
        let menu = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.tag = NSTextFinder.Action.hideFindInterface.rawValue
        self.editArea.performTextFinderAction(menu)
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
            vc.sidebarOutlineView.deselectAll(nil)
        }

        let value = sender.stringValue
        let inlineTags = vc.sidebarOutlineView.getSelectedInlineTags()

        if (value.count > 0) {
            search.stringValue = String()
            editArea.clear()
            var content = String()

            let selectedProject = sidebarOutlineView.getSidebarProjects()?.first ?? Storage.sharedInstance().getRootProject()

            if UserDefaultsManagement.fileFormat == .Markdown,
                UserDefaultsManagement.naming == .autoRename,
                UserDefaultsManagement.autoInsertHeader,
                UserDefaultsManagement.firstLineAsTitle || selectedProject?.firstLineAsTitle == true {
                content.append("# \(value)\n\n")
            }

            if (inlineTags.count > 0) {
                content.append(inlineTags)
            }

            createNote(name: value, content: content)
        } else {
            createNote(content: inlineTags)
        }
    }
    
    @IBAction func fileMenuNewNote(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        
        if let type = vc.getSidebarType(), type == .Trash {
            vc.sidebarOutlineView.deselectAll(nil)
        }

        let inlineTags = vc.sidebarOutlineView.getSelectedInlineTags()

        vc.createNote(content: inlineTags)
    }

    @IBAction func importNote(_ sender: NSMenuItem) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.begin { (result) -> Void in
            if result == NSApplication.ModalResponse.OK {
                let urls = panel.urls
                let project = self.getSidebarProject() ?? self.storage.getMainProject()

                for url in urls {
                    _ = self.copy(project: project, url: url)
                }
            }
        }
    }

    @IBAction func fileMenuNewRTF(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        
        if let type = vc.getSidebarType(), type == .Trash {
            vc.sidebarOutlineView.deselectAll(nil)
        }
        
        vc.createNote(type: .RichText)
    }
    
    @IBAction func moveMenu(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        
        if vc.notesTableView.selectedRow >= 0 {
            vc.loadMoveMenu()

            let moveTitle = NSLocalizedString("Move", comment: "Menu")
            let moveMenu = vc.noteMenu.item(withTitle: moveTitle)
            let view = vc.notesTableView.rect(ofRow: vc.notesTableView.selectedRow)
            let x = vc.splitView.subviews[0].frame.width + 5
            let general = moveMenu?.submenu?.item(at: 0)

            moveMenu?.submenu?.popUp(positioning: general, at: NSPoint(x: x, y: view.origin.y + 8), in: vc.notesTableView)
        }
    }

    @IBAction func historyMenu(_ sender: Any) {
        guard let vc = ViewController.shared(), let note = vc.notesTableView.getSelectedNote() else { return }

        if vc.notesTableView.selectedRow >= 0 {
            let moveMenu = NSMenu()

            let git = Git.sharedInstance()
            let repository = git.getRepository(by: note.project.getParent())
            let commits = repository.getCommits(by: note.getGitPath())

            if commits.count == 0 {
                return
            }

            for commit in commits {
                let menuItem = NSMenuItem()
                if let date = commit.getDate() {
                    menuItem.title = date
                }

                menuItem.representedObject = commit
                menuItem.action = #selector(vc.checkoutRevision(_:))
                moveMenu.addItem(menuItem)
            }

            let view = vc.notesTableView.rect(ofRow: vc.notesTableView.selectedRow)
            let x = vc.splitView.subviews[0].frame.width + 5
            let general = moveMenu.item(at: 0)

            moveMenu.popUp(positioning: general, at: NSPoint(x: x, y: view.origin.y + 8), in: vc.notesTableView)
        }
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
    
    @IBAction func editorMenu(_ sender: Any) {
        for index in notesTableView.selectedRowIndexes {
            external(selectedRow: index)
        }
    }
    
    @IBAction func finderMenu(_ sender: NSMenuItem) {
        if let notes = notesTableView.getSelectedNotes() {
            var urls = [URL]()
            for note in notes {
                urls.append(note.url)
            }
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }
    
    @IBAction func makeMenu(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        
        if let type = vc.getSidebarType(), type == .Trash {
            vc.sidebarOutlineView.deselectAll(nil)
        }
        
        vc.createNote()
    }
    
    @IBAction func pinMenu(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        vc.pin(vc.notesTableView.selectedRowIndexes)
    }
    
    @IBAction func renameMenu(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        vc.titleLabel.restoreResponder = vc.view.window?.firstResponder

        switchTitleToEditMode()
    }
    
    @objc func switchTitleToEditMode() {
        guard let vc = ViewController.shared() else { return }

        if vc.notesTableView.selectedRow > -1 {
            vc.titleLabel.editModeOn()
            vc.titleBarAdditionalView.alphaValue = 0
            
            if let note = EditTextView.note, note.getFileName().isValidUUID {
                vc.titleLabel.stringValue = note.getFileName()
            }

            return
        }

        if let appd = NSApplication.shared.delegate as? AppDelegate,
            let md = appd.mainWindowController {
            md.maximizeWindow()
        }
    }

    @IBAction func deleteNote(_ sender: Any) {
        var forceRemove = false

        if let menuItem = sender as? NSMenuItem,
            menuItem.identifier?.rawValue == "fileMenu.forceRemove" ||
            menuItem.identifier?.rawValue == "context.fileMenu.forceRemove" {
            forceRemove = true
        }

        guard let vc = ViewController.shared() else { return }
        guard let notes = vc.notesTableView.getSelectedNotes() else {
            return
        }

        let si = vc.getSidebarItem()
        if si?.isTrash() == true || forceRemove {
            removeForever()
            return
        }
        
        let selectedRow = vc.notesTableView.selectedRowIndexes.min()

        UserDataService.instance.searchTrigger = true

        vc.notesTableView.removeByNotes(notes: notes)

        // Delete tags
        for note in notes {
            let tags = note.tags
            note.tags.removeAll()
            vc.sidebarOutlineView.removeTags(tags)
        }

        vc.storage.removeNotes(notes: notes) { urls in
            if let appd = NSApplication.shared.delegate as? AppDelegate,
                let md = appd.mainWindowController
            {
                let undoManager = md.notesListUndoManager

                if let ntv = vc.notesTableView {
                    undoManager.registerUndo(withTarget: ntv, selector: #selector(ntv.unDelete), object: urls)
                    undoManager.setActionName(NSLocalizedString("Delete", comment: ""))
                }

                if let i = selectedRow, i > -1 {
                    if vc.notesTableView.noteList.count > i {
                        vc.notesTableView.selectRow(i)
                    } else {
                        vc.notesTableView.selectRow(vc.notesTableView.noteList.count - 1)
                    }
                }

                UserDataService.instance.searchTrigger = false
            }

            vc.editArea.clear()
        }

        NSApp.mainWindow?.makeFirstResponder(vc.notesTableView)
    }
    
    @IBAction func archiveNote(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        
        guard let notes = vc.notesTableView.getSelectedNotes() else {
            return
        }
        
        if let project = storage.getArchive() {
            move(notes: notes, project: project)
        }
    }

    @IBAction func changeCreationDate(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        guard let notes = vc.notesTableView.getSelectedNotes() else { return }
        guard let note = notes.first else { return }
        guard let creationDate = note.getFileCreationDate() else { return }
        guard let window = MainWindowController.shared() else { return }

        vc.alert = NSAlert()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.string(from: creationDate)

        field.stringValue = date
        field.placeholderString = "2020-08-28 21:59:07"

        vc.alert?.messageText = NSLocalizedString("Change creation date", comment: "Menu") + ":"
        vc.alert?.accessoryView = field
        vc.alert?.alertStyle = .informational
        vc.alert?.addButton(withTitle: "OK")
        vc.alert?.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                let date = field.stringValue
                let userDate = formatter.date(from: date)
                let attributes = [FileAttributeKey.creationDate: userDate]

                for note in notes {
                    do {
                        try FileManager.default.setAttributes(attributes as [FileAttributeKey : Any], ofItemAtPath: note.url.path)

                        note.creationDate = userDate
                        self.notesTableView.reloadRow(note: note)
                    } catch {
                        print(error)
                    }
                }
            }

            vc.alert = nil
        }

        field.becomeFirstResponder()
    }

    @IBAction func openInExternalEditor(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        vc.external(selectedRow: vc.notesTableView.selectedRow)
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

        vc.editArea.updateTextContainerInset()
    }
    
    @IBAction func toggleSidebar(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }

        let size = Int(vc.sidebarSplitView.subviews[0].frame.width)

        if size != 0 {
            UserDefaultsManagement.realSidebarSize = size
            vc.sidebarSplitView.setPosition(0, ofDividerAt: 0)
        } else {
            vc.sidebarSplitView.setPosition(CGFloat(UserDefaultsManagement.realSidebarSize), ofDividerAt: 0)
        }

        vc.editArea.updateTextContainerInset()
    }
    
    @IBAction func emptyTrash(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }
        
        if let sidebarItem = vc.getSidebarItem(), sidebarItem.isTrash() {
            let indexSet = IndexSet(integersIn: 0..<vc.notesTableView.noteList.count)
            vc.notesTableView.removeRows(at: indexSet, withAnimation: .effectFade)
        }
        
        let notes = storage.getAllTrash()
        for note in notes {
            _ = note.removeFile()
        }
        
        NSSound(named: "Pop")?.play()
    }
    
    @IBAction func printNotes(_ sender: NSMenuItem) {
        if let note = EditTextView.note, note.isMarkdown() {
            printMarkdownPreview()
            return
        }

        let pv = NSTextView(frame: NSMakeRect(0, 0, 528, 688))
        pv.textStorage?.append(editArea.attributedString())
        
        let printInfo = NSPrintInfo.shared
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.scalingFactor = 1
        printInfo.topMargin = 40
        printInfo.leftMargin = 40
        printInfo.rightMargin = 40
        printInfo.bottomMargin = 40
        
        let operation: NSPrintOperation = NSPrintOperation(view: pv, printInfo: printInfo)
        operation.printPanel.options.insert(NSPrintPanel.Options.showsPaperSize)
        operation.printPanel.options.insert(NSPrintPanel.Options.showsOrientation)
        operation.run()
    }
    
    @IBAction func toggleNotesLock(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        guard var notes = vc.notesTableView.getSelectedNotes() else { return }

        notes = lockUnlocked(notes: notes)
        guard notes.count > 0 else { return }

        getMasterPassword() { password, isTypedByUser in
            guard password.count > 0 else { return }

            for note in notes {
                var success = false

                if note.container == .encryptedTextPack {
                    success = note.unLock(password: password)
                    if success && notes.count == 0x01 {
                        note.password = password
                        DispatchQueue.main.async {
                            self.refillEditArea(force: true)
                        }
                    }
                } else {
                    success = note.encrypt(password: password)
                    if success && notes.count == 0x01 {
                        note.password = nil
                        DispatchQueue.main.async {
                            self.refillEditArea(force: true)
                        }
                        self.focusTable()
                    }
                }

                if success && isTypedByUser {
                    self.save(password: password)
                }

                self.notesTableView.reloadRow(note: note)
            }
        }
    }

    @IBAction func removeNoteEncryption(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }
        guard var notes = vc.notesTableView.getSelectedNotes() else { return }

        notes = decryptUnlocked(notes: notes)
        guard notes.count > 0 else { return }

        UserDataService.instance.fsUpdatesDisabled = true
        getMasterPassword() { password, isTypedByUser in
            for note in notes {
                if note.container == .encryptedTextPack {
                    let success = note.unEncrypt(password: password)
                    if success && notes.count == 0x01 {
                        note.password = nil
                        DispatchQueue.main.async {
                            self.refillEditArea(force: true)
                        }
                    }
                }
                self.notesTableView.reloadRow(note: note)
            }
            UserDataService.instance.fsUpdatesDisabled = false
        }
    }

    @IBAction func lockAll(_ sender: Any) {
        let notes = storage.noteList.filter({ $0.isUnlocked() })
        for note in notes {
            if note.lock() {
                notesTableView.reloadRow(note: note)
            }
        }

        editArea.clear()
        refillEditArea(force: true)
        NSApp.mainWindow?.makeFirstResponder(notesTableView)
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

    public func blockFSUpdates() {
        timer.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(enableFSUpdates), userInfo: nil, repeats: false)

        UserDataService.instance.fsUpdatesDisabled = true
    }
    
    // Changed main edit view
    func textDidChange(_ notification: Notification) {
        guard let note = getCurrentNote() else { return }

        Git.sharedInstance().cleanCheckoutHistory()

        blockFSUpdates()

        if (
            currentPreviewState == .off
            && self.editArea.isEditable
        ) {
            editArea.removeHighlight()
            editArea.saveImages()

            note.save(attributed: editArea.attributedString())
            reSort(note: note)
        }

        breakUndoTimer.invalidate()
        breakUndoTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(breakUndo), userInfo: nil, repeats: true)
    }

    public func reSort(note: Note) {
        if !updateViews.contains(note) {
            updateViews.append(note)
        }

        rowUpdaterTimer.invalidate()
        rowUpdaterTimer = Timer.scheduledTimer(timeInterval: 1.2, target: self, selector: #selector(updateTableViews), userInfo: nil, repeats: false)
    }

    public func getCurrentNote() -> Note? {
        return EditTextView.note
    }

    private func removeForever() {
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
                vc.editArea.clear()
                vc.storage.removeNotes(notes: notes, completely: true) { _ in
                    DispatchQueue.main.async {
                        vc.notesTableView.removeByNotes(notes: notes)
                        if let i = selectedRow, i > -1 {
                            vc.notesTableView.selectRow(i)
                        }
                    }
                }
            }

            vc.alert = nil
        }
    }
    
    @objc func enableFSUpdates() {
        UserDataService.instance.fsUpdatesDisabled = false
    }

    @objc private func updateTableViews() {
        notesTableView.beginUpdates()
        for note in updateViews {
            notesTableView.reloadRow(note: note)

            if UserDefaultsManagement.sort == .modificationDate
                && UserDefaultsManagement.sortDirection == true
                && note.project.sortBy == .none
                && search.stringValue.count == 0 {

                if let index = notesTableView.noteList.firstIndex(of: note) {
                    moveNoteToTop(note: index)
                }
            } else {
                let project = getSidebarProject()
                sortAndMove(note: note, project: project)
            }
        }

        updateViews.removeAll()
        notesTableView.endUpdates()
    }
    
    func getSidebarProject() -> Project? {
        if sidebarOutlineView.selectedRow < 0 {
            return nil
        }
        
        if let sidebarItem = sidebarOutlineView.item(atRow: sidebarOutlineView.selectedRow) as? SidebarItem,
           sidebarItem.project != nil {
            return sidebarItem.project
        }

        if let project = sidebarOutlineView.item(atRow: sidebarOutlineView.selectedRow) as? Project {
            return project
        }
        
        return nil
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

    private var selectRowTimer = Timer()

    func updateTable(search: Bool = false, searchText: String? = nil, sidebarItem: SidebarItem? = nil, projects: [Project]? = nil, tags: [String]? = nil, saveHistory: Bool = false, completion: @escaping () -> Void = {}) {

        var sidebarItem: SidebarItem? = sidebarItem
        var projects: [Project]? = projects
        var tags: [String]? = tags
        var sidebarName: String? = nil

        let timestamp = Date().toMillis()

        self.search.timestamp = timestamp
        self.searchQueue.cancelAllOperations()

        if searchText == nil {
            projects = sidebarOutlineView.getSidebarProjects()
            tags = sidebarOutlineView.getSidebarTags()
            sidebarItem = getSidebarItem()

            if !UserDefaultsManagement.inlineTags {
                sidebarName = getSidebarItem()?.getName()
            }
        }

        var filter = searchText ?? self.search.stringValue
        let originalFilter = searchText ?? self.search.stringValue
        filter = originalFilter

        var type = sidebarItem?.type

        // Global search if sidebar not checked
        if type == nil && projects == nil {
            type = .All
        }

        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self] in
            guard let self = self else {return}

            if let projects = projects {
                for project in projects {
                    self.preLoadNoteTitles(in: project)
                }
            }

            var terms = filter.split(separator: " ")
            let source = self.storage.noteList
            var notes = [Note]()
            
            if let type = type, type == .Todo {
                terms.append("- [ ]")
            }
            
            for note in source {
                if operation.isCancelled {
                    completion()
                    return
                }

                if (self.isFit(note: note, filter: filter, terms: terms, projects: projects, tags: tags, type: type, sidebarName: sidebarName)) {
                    notes.append(note)
                }
            }

            let orderedNotesList = self.storage.sortNotes(noteList: notes, filter: filter, project: projects?.first, operation: operation)

            // Check diff
            if orderedNotesList == self.notesTableView.noteList {
                completion()
                return
            }

            self.notesTableView.noteList = orderedNotesList

            if operation.isCancelled {
                completion()
                return
            }
            
            guard self.notesTableView.noteList.count > 0 else {
                DispatchQueue.main.async {
                    self.editArea.clear()
                    self.notesTableView.reloadData()
                    completion()
                }
                return
            }

            let note = self.notesTableView.noteList[0]

            DispatchQueue.main.async {
                self.notesTableView.reloadData()

                if search {
                    if (self.notesTableView.noteList.count > 0) {
                        if filter.count > 0 && (
                            UserDefaultsManagement.textMatchAutoSelection
                            || note.title.lowercased().startsWith(string: self.search.stringValue.lowercased())
                            || note.fileName.lowercased().startsWith(string: self.search.stringValue.lowercased())
                        ) {

                            let note = self.notesTableView.noteList.first(where: { $0.title == originalFilter })
                                ?? self.notesTableView.noteList.first

                            if let note = note {
                                if saveHistory {
                                    self.notesTableView.saveNavigationHistory(note: note)
                                }

                                self.selectNullTableRow(note: note)
                            }
                        } else {
                            self.editArea.clear()
                        }
                    } else {
                        self.editArea.clear()
                    }
                } 

                completion()
            }
        }
        
        self.searchQueue.addOperation(operation)
    }

    /*
     Load titles in cases sort by Title
     */
    private func preLoadNoteTitles(in project: Project) {
        if (UserDefaultsManagement.sort == .title || project.sortBy == .title) && (UserDefaultsManagement.firstLineAsTitle || project.firstLineAsTitle) {
            let notes = storage.noteList.filter({ $0.project == project })
            for note in notes {
                note.loadPreviewInfo()
            }
        }
    }

    private func isMatched(note: Note, terms: [Substring]) -> Bool {
        for term in terms {
            if note.name.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: nil) != nil ||
                note.content.string.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: nil) != nil {
                continue
            }
            
            return false
        }
        
        return true
    }

    public func isFit(note: Note, filter: String = "", terms: [Substring]? = nil, shouldLoadMain: Bool = false, projects: [Project]? = nil, tags: [String]? = nil, type: SidebarItemType? = nil, sidebarName: String? = nil) -> Bool {
        var filter = filter
        var terms = terms
        var projects = projects
        var tags = tags
        var type = type

        if shouldLoadMain {

            projects = sidebarOutlineView.getSidebarProjects()
            tags = sidebarOutlineView.getSidebarTags()

            type = getSidebarType()
            if type == nil && projects == nil && tags == nil {
                type = .All
            }
            
            filter = search.stringValue
            terms = search.stringValue.split(separator: " ")

            if type == .Todo {
                terms!.append("- [ ]")
            }
        }

        return !note.name.isEmpty
            && (
                filter.isEmpty && type != .Todo
                    || type == .Todo && self.isMatched(note: note, terms: ["- [ ]"])
                    || self.isMatched(note: note, terms: terms!)
            ) && (
                type == .All && !note.project.isArchive && note.project.showInCommon
                || type != .All && type != .Todo && projects != nil && projects!.contains(note.project)
                || type == .Trash
                || type == .Untagged && note.tags.count == 0
                || type == .Todo && note.project.showInCommon
                || type == .Archive && note.project.isArchive
                || !UserDefaultsManagement.inlineTags && tags != nil
                || projects?.contains(note.project) == true
            ) && (
                type == .Trash && note.isTrash()
                    || type != .Trash && !note.isTrash()
            ) && (
                tags == nil
                || UserDefaultsManagement.inlineTags && tags != nil && note.tags.filter({ tags != nil && self.contains(tag: $0, in: tags!) }).count > 0
            )
    }

    public func contains(tag name: String, in tags: [String]) -> Bool {
        var found = false
        for tag in tags {
            if name == tag || name.starts(with: tag + "/") {
                found = true
                break
            }
        }
        return found
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
    
    func focusEditArea() {
        guard let note = EditTextView.note,
            currentPreviewState == .off || note.isRTF(),
            note.container != .encryptedTextPack
        else { return }

        editArea.window?.makeFirstResponder(editArea)

        if (notesTableView.selectedRow > -1) {
            editArea.isEditable = true
            emptyEditAreaImage.isHidden = true
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
        search.cleanFindPasteboard()

        if shouldBecomeFirstResponder {
            search.becomeFirstResponder()
        }

        notesTableView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
        editArea.clear()

        let searchText = completion == nil ? "" : nil

        self.updateTable(searchText: searchText) {
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
            let project = Storage.sharedInstance().getMainProject()
            createNote(content: clipboard!, project: project)
            
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
        let isPinned = notesTableView.noteList[index].isPinned
        let position = isPinned ? 0 : notesTableView.countVisiblePinned()
        let note = notesTableView.noteList.remove(at: index)

        notesTableView.noteList.insert(note, at: position)

        notesTableView.reloadRow(note: note)
        notesTableView.moveRow(at: index, to: position)
        notesTableView.scrollRowToVisible(0)
    }
    
    func createNote(name: String = "", content: String = "", type: NoteType? = nil, project: Project? = nil, load: Bool = false) {
        guard let vc = ViewController.shared() else { return }

        let selectedProjects = vc.sidebarOutlineView.getSidebarProjects()
        var sidebarProject = project ?? selectedProjects?.first
        var text = content
        
        if let type = vc.getSidebarType(), type == .Todo, content.count == 0 {
            text = "- [ ] "
        }
        
        if sidebarProject == nil {
            sidebarProject = Storage.sharedInstance().getRootProject()
        }
        
        guard let project = sidebarProject else { return }

        let note = Note(name: name, project: project, type: type)
        note.content = NSMutableAttributedString(string: text)
        note.save()

        _ = note.scanContentTags()

        if let selectedProjects = selectedProjects, !selectedProjects.contains(project) {
            return
        }

        disablePreview()
        notesTableView.deselectNotes()
        editArea.string = text
        EditTextView.note = note

        search.stringValue.removeAll()

        updateTable() {
            DispatchQueue.main.async {
                self.notesTableView.saveNavigationHistory(note: note)
                if let index = self.notesTableView.getIndex(note) {
                    self.notesTableView.selectRowIndexes([index], byExtendingSelection: false)
                    self.notesTableView.scrollRowToVisible(index)
                }
            
                self.focusEditArea()
            }
        }
    }

    public func sortAndMove(note: Note, project: Project? = nil) {
        guard let srcIndex = notesTableView.noteList.firstIndex(of: note) else { return }
        let notes = notesTableView.noteList

        let resorted = storage.sortNotes(noteList: notes, filter: self.search.stringValue, project: project)
        guard let dstIndex = resorted.firstIndex(of: note) else { return }

        if srcIndex != dstIndex {
            notesTableView.moveRow(at: srcIndex, to: dstIndex)
            notesTableView.noteList = resorted
        }
    }
    
    func pin(_ selectedRows: IndexSet) {
        guard !selectedRows.isEmpty else { return }

        var state = notesTableView.noteList
        var updatedNotes = [(Int, Note)]()
        for row in selectedRows {
            guard let rowView = notesTableView.rowView(atRow: row, makeIfNecessary: false) as? NoteRowView,
                let cell = rowView.view(atColumn: 0) as? NoteCellView,
                let note = cell.objectValue as? Note
            else { continue }

            updatedNotes.append((row, note))
            note.togglePin()
            cell.renderPin()
        }

        let resorted = storage.sortNotes(noteList: notesTableView.noteList, filter: self.search.stringValue)
        let indexes = updatedNotes.compactMap({ _, note in resorted.firstIndex(where: { $0 === note }) })
        let newIndexes = IndexSet(indexes)

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
        notesTableView.reloadData(forRowIndexes: newIndexes, columnIndexes: [0])
        notesTableView.selectRowIndexes(newIndexes, byExtendingSelection: false)
        notesTableView.endUpdates()
    }

    func external(selectedRow: Int) {
        if (notesTableView.noteList.indices.contains(selectedRow)) {
            let note = notesTableView.noteList[selectedRow]

            var path = note.url.path
            if note.isTextBundle() && !note.isUnlocked(), let url = note.getContentFileURL() {
                path = url.path
            }

            NSWorkspace.shared.openFile(path, withApplication: UserDefaultsManagement.externalEditor)
        }
    }

    @IBAction func togglePreview(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }

        let firstResp = NSApp.mainWindow?.firstResponder

        if (vc.currentPreviewState == .on) {
            vc.disablePreview()
        } else {
            //Preview mode doesn't support text search
            vc.cancelTextSearch()
            vc.currentPreviewState = .on
            vc.refillEditArea()
        }

        if let responder = firstResp, (
            search.currentEditor() == firstResp
            || responder.isKind(of: NotesTableView.self)
            || responder.isKind(of: SidebarOutlineView.self)
        ) {
            NSApp.mainWindow?.makeFirstResponder(firstResp)
        } else {
            let responder = vc.currentPreviewState == .on ? notesTableView : editArea
            NSApp.mainWindow?.makeFirstResponder(responder)
        }

        UserDefaultsManagement.preview = vc.currentPreviewState == .on
        editArea.userActivity?.needsSave = true
    }

    func disablePreview() {
        currentPreviewState = .off

        editArea.markdownView?.removeFromSuperview()
        editArea.markdownView = nil
        
        guard let editor = editArea else { return }
        editor.subviews.removeAll(where: { $0.isKind(of: MPreviewView.self) })

        refillEditArea()
    }
    
    public func restoreCurrentPreviewState() {
        currentPreviewState = UserDefaultsManagement.preview ? .on : .off
    }

    private func configureTranslation() {
        let creationDate = NSLocalizedString("Change creation date", comment: "Menu")

        menuChangeCreationDate.title = creationDate
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
        
        if !note.isInArchive() {
            let archiveMenu = NSMenuItem()
            archiveMenu.title = NSLocalizedString("Archive", comment: "Sidebar label")
            archiveMenu.action = #selector(vc.archiveNote(_:))
            moveMenu.addItem(archiveMenu)
            moveMenu.addItem(NSMenuItem.separator())
        }
        
        if !note.isTrash() {
            let trashMenu = NSMenuItem()
            trashMenu.title = NSLocalizedString("Trash", comment: "Sidebar label")
            trashMenu.action = #selector(vc.deleteNote(_:))
            trashMenu.tag = 555
            moveMenu.addItem(trashMenu)
            moveMenu.addItem(NSMenuItem.separator())
        }
                
        let projects = storage.getProjects()
        for item in projects {
            if note.project == item || item.isTrash || item.isArchive {
                continue
            }
            
            let menuItem = NSMenuItem()
            menuItem.title = item.getFullLabel()
            menuItem.representedObject = item
            menuItem.action = #selector(vc.moveNote(_:))
            moveMenu.addItem(menuItem)
        }

        noteMenu.setSubmenu(moveMenu, for: moveMenuItem)
        loadHistory()
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
        let keyStore = NSUbiquitousKeyValueStore()
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.ubiquitousKeyValueStoreDidChange), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: keyStore)
        
        keyStore.synchronize()
    }
    
    @objc func ubiquitousKeyValueStoreDidChange(notification: NSNotification) {
        if let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            for key in keys {
                if key == "co.fluder.fsnotes.pins.shared" {
                    let changedNotes = storage.restoreCloudPins()

                    if let notes = changedNotes.added {
                        for note in notes {
                            if let i = notesTableView.getIndex(note) {
                                self.moveNoteToTop(note: i)
                            }
                        }
                    }

                    if let notes = changedNotes.removed {
                        for note in notes {
                            if let i = notesTableView.getIndex(note) {
                                notesTableView.reloadData(forRowIndexes: [i], columnIndexes: [0])
                            }
                        }
                    }
                }
            }
        }
    }
    
    func checkSidebarConstraint() {
        if sidebarSplitView.subviews[0].frame.width > 50 {
            searchTopConstraint.constant = 8
            newNoteTopConstraint.constant = 2
            return
        }
        
        if UserDefaultsManagement.hideRealSidebar || sidebarSplitView.subviews[0].frame.width < 50 {
            
            searchTopConstraint.constant = CGFloat(25)
            newNoteTopConstraint.constant = CGFloat(20)
            return
        }
        
        searchTopConstraint.constant = 8
        newNoteTopConstraint.constant = 2
    }

    @IBAction func duplicate(_ sender: Any) {
        if let notes = notesTableView.getSelectedNotes() {
            for note in notes {
                let src = note.url
                let dst = NameHelper.generateCopy(file: note.url)

                if note.isTextBundle() || note.isEncrypted() {
                    try? FileManager.default.copyItem(at: src, to: dst)
                    
                    continue
                }

                let name = dst.deletingPathExtension().lastPathComponent
                let noteDupe = Note(name: name, project: note.project, type: note.type, cont: note.container)
                noteDupe.content = NSMutableAttributedString(string: note.content.string)

                // Clone images
                if note.type == .Markdown && note.container == .none {
                    let images = note.getAllImages()
                    for image in images {
                        noteDupe.move(from: image.url, imagePath: image.path, to: note.project, copy: true)
                    }
                }

                noteDupe.save()

                storage.add(noteDupe)
                notesTableView.insertNew(note: noteDupe)
            }
        }
    }
        
    @IBAction func copyURL(_ sender: Any) {
        if let note = notesTableView.getSelectedNote(), let title = note.title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {

            let name = "fsnotes://find?id=\(title)"
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(name, forType: NSPasteboard.PasteboardType.string)
            
            let notification = NSUserNotification()
            notification.title = "FSNotes"
            notification.informativeText = NSLocalizedString("URL has been copied to clipboard", comment: "") 
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
    
    @IBAction func copyTitle(_ sender: Any) {
        if let note = notesTableView.getSelectedNote() {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(note.title, forType: NSPasteboard.PasteboardType.string)
        }
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
            case 4:
                UserDefaultsManagement.sidebarVisibilityArchive = isChecked
            case 5:
                UserDefaultsManagement.sidebarVisibilityTrash = isChecked
            case 6:
                UserDefaultsManagement.sidebarVisibilityUntagged = isChecked
            default:
                break
        }

        ViewController.shared()?.sidebarOutlineView.reloadSidebar()
    }

    func updateTitle(note: Note) {
        var titleString = note.getFileName()

        if titleString.isValidUUID {
            titleString = String()
        }

        if titleString.count > 0 {
            titleLabel.stringValue = note.project.getNestedLabel() + " › " + titleString
        } else {
            titleLabel.stringValue = note.project.getNestedLabel()
        }

        titleLabel.currentEditor()?.selectedRange = NSRange(location: 0, length: 0)
        
        MainWindowController.shared()?.title = titleLabel.stringValue
    }

    public func dropTitle() {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "FSNotes"

        titleLabel.stringValue = appName
        MainWindowController.shared()?.title = appName
    }
    
    //MARK: Share Service
    
    @IBAction func shareSheet(_ sender: NSButton) {
        if let note = notesTableView.getSelectedNote() {
            let sharingPicker = NSSharingServicePicker(items: [
                note.content,
                note.url
            ])
            sharingPicker.delegate = self
            sharingPicker.show(relativeTo: NSZeroRect, of: sender, preferredEdge: .minY)
        }
    }
    
    public func saveTextAtClipboard() {
        if let note = notesTableView.getSelectedNote() {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(note.content.string, forType: NSPasteboard.PasteboardType.string)
        }
    }
    
    public func saveHtmlAtClipboard() {
        if let note = notesTableView.getSelectedNote() {
            if let render = renderMarkdownHTML(markdown: note.content.string) {
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                pasteboard.setString(render, forType: NSPasteboard.PasteboardType.string)
            }
        }
    }

    @IBAction func textFinder(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }

        if !vc.editAreaScroll.isFindBarVisible, [NSFindPanelAction.next.rawValue, NSFindPanelAction.previous.rawValue].contains(UInt(sender.tag)) {

            if vc.currentPreviewState == .on && vc.notesTableView.selectedRow > -1 {
                vc.disablePreview()
            }

            let menu = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            menu.tag = NSTextFinder.Action.showFindInterface.rawValue
            vc.editArea.performTextFinderAction(menu)
        }

        vc.editArea.performTextFinderAction(sender)
    }

    @IBAction func prevHistory(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }

        if vc.notesTableView.historyPosition > 0 {
            let prev = vc.notesTableView.historyPosition - 1
            let prevUrl = vc.notesTableView.history[prev]

            if let note = Storage.sharedInstance().getBy(url: prevUrl) {
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

            if let note = Storage.sharedInstance().getBy(url: nextUrl) {
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
        }

        return menu
    }

    func splitViewWillResizeSubviews(_ notification: Notification) {
        editArea.updateTextContainerInset()
    }

    public static func shared() -> ViewController? {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return nil }
        
        return delegate.mainWindowController?.window?.contentViewController as? ViewController
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
    
    public func unLock(notes: [Note]) {
        getMasterPassword() { password, isTypedByUser in
            guard password.count > 0 else { return }

            var i = 0
            for note in notes {
                let success = note.unLock(password: password)
                if success, i == 0 {
                    note.password = password

                    DispatchQueue.main.async {
                        self.refillEditArea(force: true)
                    }

                    if isTypedByUser {
                        self.save(password: password)
                    }
                }

                self.notesTableView.reloadRow(note: note)
                i = i + 1
            }
        }
    }

    private func getMasterPassword(completion: @escaping (String, Bool) -> ()) {
        if #available(OSX 10.12.2, *), UserDefaultsManagement.allowTouchID {
            let context = LAContext()
            context.localizedFallbackTitle = NSLocalizedString("Enter Master Password", comment: "")

            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
                masterPasswordPrompt(completion: completion)
                return
            }
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "To access secure data") { (success, evaluateError) in
                
                if !success {
                    self.masterPasswordPrompt(completion: completion)

                    return
                }

                do {
                    let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")
                    let password = try item.readPassword()

                    completion(password, false)
                    return
                } catch {
                    print(error)
                }

                self.masterPasswordPrompt(completion: completion)
            }
        } else {
            masterPasswordPrompt(completion: completion)
        }
    }
    
    private func masterPasswordPrompt(completion: @escaping (String, Bool) -> ()) {
        DispatchQueue.main.async {
            guard let window = MainWindowController.shared() else { return }

            self.alert = NSAlert()
            guard let alert = self.alert else { return }

            let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
            alert.messageText = NSLocalizedString("Master password:", comment: "")
            alert.informativeText = NSLocalizedString("Please enter password for current note", comment: "")
            alert.accessoryView = field
            alert.alertStyle = .informational
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
                if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                    completion(field.stringValue, true)
                }

                ViewController.shared()?.alert = nil
            }

            field.becomeFirstResponder()
        }
    }

    private func save(password: String) {
        guard password.count > 0, UserDefaultsManagement.savePasswordInKeychain else { return }

        let item = KeychainPasswordItem(service: KeychainConfiguration.serviceName, account: "Master Password")

        var oldPassword = String()
        do {
            oldPassword = try item.readPassword()
        } catch {/*_*/}

        do {
            guard oldPassword.count == 0 else { return }

            try item.savePassword(password)
        } catch {
            print("Master password saving error: \(error)")
        }
    }

    public func lockUnlocked(notes: [Note]) -> [Note] {
        var notes = notes
        var isFirst = true

        for note in notes {
            if note.isUnlocked() && note.isEncrypted() {
                if note.lock() && isFirst {
                    self.editArea.clear()
                    self.refillEditArea()
                    NSApp.mainWindow?.makeFirstResponder(self.notesTableView)
                }
                notes.removeAll { $0 === note }
            }
            isFirst = false

            self.notesTableView.reloadRow(note: note)
        }

        return notes
    }

    private func decryptUnlocked(notes: [Note]) -> [Note] {
        var notes = notes

        for note in notes {
            if note.isUnlocked() {
                if note.unEncryptUnlocked() {
                    notes.removeAll { $0 === note }
                    notesTableView.reloadRow(note: note)
                }
            }
        }

        return notes
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

    @objc func onUserSwitch(note: NSNotification) {
        if UserDefaultsManagement.lockOnUserSwitch {
            lockAll(self)
        }
    }

    override func restoreUserActivityState(_ userActivity: NSUserActivity) {
        guard let name = userActivity.userInfo?["note-file-name"] as? String,
            let position = userActivity.userInfo?["position"] as? String,
            let state = userActivity.userInfo?["state"] as? String,
            let note = Storage.sharedInstance().getBy(name: name)
        else { return }

        if state == "preview" {
            currentPreviewState = .on
        } else {
            currentPreviewState = .off
        }

        if let position = Int(position),
            position > -1,
            let textStorage = editArea.textStorage,
            textStorage.length >= position {
            
            editArea.restoreRange = NSRange(location: position, length: 0)
        }

        notesTableView.selectRowAndSidebarItem(note: note)
    }

    /*
     Needs update UserActivity if selection did change
     */
    func textViewDidChangeSelection(_ notification: Notification) {
        editArea.userActivity?.needsSave = true
    }

    @objc func doubleClickOnNotesTable() {
        let selected = notesTableView.clickedRow

        if (selected < 0) {
            return
        }

        if (notesTableView.noteList.indices.contains(selected)) {
            external(selectedRow: selected)
        }
    }

    @objc func breakUndo() {
        if (
           currentPreviewState == .off
           && editArea.isEditable
        ) {
            editArea.breakUndoCoalescing()
        }
    }
}
