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

class ViewController: NSViewController,
    NSTextViewDelegate,
    NSTextFieldDelegate,
    NSSplitViewDelegate,
    NSOutlineViewDelegate,
    NSOutlineViewDataSource {
    // MARK: - Properties
    public var fsManager: FileSystemEventManager?
    let storage = Storage.sharedInstance()
    var filteredNoteList: [Note]?
    var alert: NSAlert?
    var refilled: Bool = false
    var timer = Timer()
    var sidebarTimer = Timer()
    let searchQueue = OperationQueue()
    

    override var representedObject: Any? {
        didSet { }  // Update the view, if already loaded.
    }

    // MARK: - IBOutlets
    @IBOutlet var emptyEditAreaImage: NSImageView!
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var searchWrapper: NSTextField!
    @IBOutlet var editArea: EditTextView!
    @IBOutlet weak var editAreaScroll: NSScrollView!
    @IBOutlet weak var search: SearchTextField!
    @IBOutlet weak var notesTableView: NotesTableView!
    @IBOutlet var noteMenu: NSMenu!
    @IBOutlet weak var storageOutlineView: SidebarProjectView!
    @IBOutlet weak var sidebarSplitView: NSSplitView!
    @IBOutlet weak var notesListCustomView: NSView!
    @IBOutlet weak var searchTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var shareButton: NSButton!
    @IBOutlet weak var sortByOutlet: NSMenuItem!

    // MARK: - Overrides
    
    override func viewDidLoad() {
        self.storage.loadDocuments()
        
        self.configureShortcuts()
        self.configureDelegates()
        self.configureLayout()
        self.configureNotesList()
        
        self.fsManager = FileSystemEventManager(storage: storage, delegate: self)
        self.fsManager?.start()

        self.loadMoveMenu()
        self.loadSortBySetting()
        self.checkSidebarConstraint()
        
        #if CLOUDKIT
            self.registerKeyValueObserver()
        #endif
        
        searchQueue.maxConcurrentOperationCount = 1
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return false}
        
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
                if menuItem.identifier?.rawValue == "fileMenu.delete" {
                    if !UserDefaultsManagement.focusInEditorOnNoteSelect && vc.editArea.hasFocus() {
                        return false
                    }
                    
                    menuItem.keyEquivalentModifierMask =
                        UserDefaultsManagement.focusInEditorOnNoteSelect
                            ? [.command, .option]
                            : [.command]
                }
                
                if ["fileMenu.new", "fileMenu.newRtf", "fileMenu.searchAndCreate"].contains(menuItem.identifier?.rawValue) {
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
            default:
                break
            }
        }
        
        return true
    }
    
    // MARK: - Initial configuration
    
    private func configureLayout() {
        self.titleLabel.stringValue = "FSNotes"
        
        self.editArea.textContainerInset.height = 0
        self.editArea.textContainerInset.width = 5
        self.editArea.isEditable = false
        self.editArea.backgroundColor = UserDefaultsManagement.bgColor
        self.editArea.layoutManager?.defaultAttachmentScaling = .scaleProportionallyDown
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(UserDefaultsManagement.editorLineSpacing)
        self.editArea.defaultParagraphStyle = paragraphStyle
        self.editArea.typingAttributes[.paragraphStyle] = paragraphStyle
        
        self.editArea.font = UserDefaultsManagement.noteFont
        
        if (sidebarSplitView.subviews.count > 1) {
            self.sidebarSplitView.subviews[1].viewBackgroundColor = NSColor.white
        }
        
        if (UserDefaultsManagement.horizontalOrientation) {
            self.splitView.isVertical = false
        }
        
        self.shareButton.sendAction(on: .leftMouseDown)
        self.setTableRowHeight()
        self.storageOutlineView.sidebarItems = Sidebar().getList()
        
        self.sidebarSplitView.autosaveName = NSSplitView.AutosaveName(rawValue: "SidebarSplitView")
        self.splitView.autosaveName = NSSplitView.AutosaveName(rawValue: "EditorSplitView")
    }
    
    private func configureNotesList() {
        self.updateTable() {
            let lastSidebarItem = UserDefaultsManagement.lastProject
            if let items = self.storageOutlineView.sidebarItems, items.indices.contains(lastSidebarItem) {
                self.storageOutlineView.selectRowIndexes([lastSidebarItem], byExtendingSelection: false)
            }
        }
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
            return NSEvent()
        }
    }
    
    private func configureDelegates() {
        self.editArea.delegate = self
        self.search.vcDelegate = self
        self.search.delegate = self.search
        self.sidebarSplitView.delegate = self
        self.storageOutlineView.viewDelegate = self
    }
    
    // MARK: - Actions
    
    @IBAction func searchAndCreate(_ sender: Any) {
        let vc = NSApplication.shared.windows.first!.contentViewController as! ViewController
        
        vc.search.becomeFirstResponder()
    }

    @IBAction func sortBy(_ sender: NSMenuItem) {
        if let id = sender.identifier, let sortBy = SortBy(rawValue: id.rawValue) {
            UserDefaultsManagement.sort = sortBy
            UserDefaultsManagement.sortDirection = !UserDefaultsManagement.sortDirection
            
            if let submenu = sortByOutlet.submenu {
                for item in submenu.items {
                    item.state = NSControl.StateValue.off
                }
            }
            
            sender.state = NSControl.StateValue.on
            
            let viewController = NSApplication.shared.windows.first!.contentViewController as! ViewController
            
            storage.noteList = storage.sortNotes(noteList: storage.noteList, filter: viewController.search.stringValue)
            viewController.notesTableView.noteList = storage.noteList
            viewController.notesTableView.reloadData()
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
        for note in notes {
            let prevProject = note.project
            let destination = project.url.appendingPathComponent(note.name)
            do {
                note.project = project
                try FileManager.default.moveItem(at: note.url, to: destination)
            } catch {
                let alert = NSAlert.init()
                alert.messageText = NSLocalizedString("Hmm, something goes wrong 🙈", comment: "")
                alert.informativeText = String(format: NSLocalizedString("Note with name \"%@\" already exists in selected storage.", comment: ""), note.name)
                alert.runModal()
                note.project = prevProject
            }
        }
        
        editArea.clear()
        updateTable()
    }
        
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {        
        return sidebarSplitView.frame.width / 5
    }
    
    func splitViewDidResizeSubviews(_ notification: Notification) {
        let vc = NSApplication.shared.windows.first!.contentViewController as! ViewController
        vc.checkSidebarConstraint()
                
        if !refilled {
            self.refilled = true
            DispatchQueue.main.async() {
                self.refillEditArea(previewOnly: true)
                self.refilled = false
            }
        }
    }
        
    func reloadSideBar() {
        sidebarTimer.invalidate()
        sidebarTimer = Timer.scheduledTimer(timeInterval: 1.2, target: storageOutlineView, selector: #selector(storageOutlineView.reloadSidebar), userInfo: nil, repeats: false)
    }
    
    func reloadView(note: Note? = nil) {
        let notesTable = self.notesTableView!
        let selectedNote = notesTable.getSelectedNote()
        let cursor = editArea.selectedRanges[0].rangeValue.location
        
        self.updateTable() {
            if let selected = selectedNote, let index = notesTable.getIndex(selected) {
                notesTable.selectRowIndexes([index], byExtendingSelection: false)
                self.refillEditArea(cursor: cursor)
            }
        }
    }
    
    func setTableRowHeight() {
        notesTableView.rowHeight = CGFloat(16 + UserDefaultsManagement.cellSpacing)
    }
    
    func refillEditArea(cursor: Int? = nil, previewOnly: Bool = false, saveTyping: Bool = false) {
        guard !previewOnly || previewOnly && UserDefaultsManagement.preview else {
            return
        }
        
        DispatchQueue.main.async {
            var location: Int = 0
        
            if let unwrappedCursor = cursor {
                location = unwrappedCursor
            } else {
                location = self.editArea.selectedRanges[0].rangeValue.location
            }
            
            let selected = self.notesTableView.selectedRow
            if (selected > -1 && self.notesTableView.noteList.indices.contains(selected)) {
                if let note = self.notesTableView.getSelectedNote() {
                    self.editArea.fill(note: note, saveTyping: saveTyping)
                    self.editArea.setSelectedRange(NSRange.init(location: location, length: 0))
                }
            }
        }
    }
        
    public func keyDown(with event: NSEvent) -> Bool {
        guard self.alert == nil else {
            if event.keyCode == kVK_Escape, let unwrapped = alert {
                NSApp.windows[0].endSheet(unwrapped.window)
            }
            return true
        }
        
        // Return / Cmd + Return navigation
        if event.keyCode == kVK_Return {
            if let fr = NSApp.mainWindow?.firstResponder, self.alert == nil {
                if event.modifierFlags.contains(.command) {
                    if fr.isKind(of: NotesTableView.self) {
                        NSApp.mainWindow?.makeFirstResponder(self.storageOutlineView)
                        return false
                    }
                    
                    if fr.isKind(of: EditTextView.self) {
                        NSApp.mainWindow?.makeFirstResponder(self.notesTableView)
                        return false
                    }
                } else {
                    if fr.isKind(of: SidebarProjectView.self) {
                        self.notesTableView.selectNext()
                        NSApp.mainWindow?.makeFirstResponder(self.notesTableView)
                        return false
                    }
                    
                    if fr.isKind(of: NotesTableView.self) && !UserDefaultsManagement.preview {
                        NSApp.mainWindow?.makeFirstResponder(self.editArea)
                        return false
                    }
                }
            }
            
            return true
        }
        
        // Control + Tab
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
        if (event.keyCode == kVK_Escape) {
            let hasSelectedNotes = notesTableView.selectedRow > -1
            let hasSelectedBarItem = storageOutlineView.selectedRow > -1
            
            if hasSelectedBarItem && hasSelectedNotes {
                UserDefaultsManagement.lastProject = 0
                UserDataService.instance.isNotesTableEscape = true
                notesTableView.deselectAll(nil)
                NSApp.mainWindow?.makeFirstResponder(search)
                return false
            }
            
            cleanSearchAndEditArea()
            storageOutlineView.deselectAll(nil)
            updateTable()
        }
        
        // Focus search field shortcut (cmd-L)
        if (event.keyCode == kVK_ANSI_L && event.modifierFlags.contains(.command)) {
            search.becomeFirstResponder()
        }
        
        // Note edit mode and select file name (cmd-r)
        if (
            event.keyCode == kVK_ANSI_R
            && event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.shift)
        ) {
            renameNote(selectedRow: notesTableView.selectedRow)
        }
        
        // Make note shortcut (cmd-n)
        if (
            event.keyCode == kVK_ANSI_N
            && event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.shift)
        ) {
            makeNote(SearchTextField())
        }
        
        // Make note shortcut (cmd-n)
        if (
            event.keyCode == kVK_ANSI_N
            && event.modifierFlags.contains(.command)
            && event.modifierFlags.contains(.shift)
        ) {
            fileMenuNewRTF(NSTextField())
        }
        
        // Pin note shortcut (cmd-8)
        if (event.keyCode == kVK_ANSI_8 && event.modifierFlags.contains(.command)) {
            pin(notesTableView.selectedRowIndexes)
        }
        
        // Next note (cmd-j)
        if (
            event.keyCode == kVK_ANSI_J
            && event.modifierFlags.contains([.command])
            && !event.modifierFlags.contains(.option)
        ) {
            notesTableView.selectNext()
        }
        
        // Prev note (cmd-k)
        if (event.keyCode == kVK_ANSI_K && event.modifierFlags.contains(.command)) {
            notesTableView.selectPrev()
        }
                
        // Open in external editor (cmd-control-e)
        if (
            event.keyCode == kVK_ANSI_E
            && event.modifierFlags.contains(.command)
            && event.modifierFlags.contains(.control)
        ) {
            external(selectedRow: notesTableView.selectedRow)
        }
        
        // Open in finder (cmd-shift-r)
        if (
            event.keyCode == kVK_ANSI_R
            && event.modifierFlags.contains(.command)
            && event.modifierFlags.contains(.shift)
        ) {
            finder(selectedRow: notesTableView.selectedRow)
        }
        
        // Toggle sidebar cmd+shift+control+b
        if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && event.modifierFlags.contains(.control) && event.keyCode == kVK_ANSI_B {
            toggleSidebar("")
        }
        
        return true
    }
    
    @IBAction func makeNote(_ sender: SearchTextField) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        
        if let type = vc.getSidebarType(), type == .Trash {
            vc.storageOutlineView.deselectAll(nil)
        }
        
        let value = sender.stringValue
        if (value.count > 0) {
            search.stringValue = ""
            editArea.clear()
            createNote(name: value)
        } else {
            createNote()
        }
    }
    
    @IBAction func fileMenuNewNote(_ sender: Any) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        
        if let type = vc.getSidebarType(), type == .Trash {
            vc.storageOutlineView.deselectAll(nil)
        }
        
        vc.createNote()
    }
    
    @IBAction func fileMenuNewRTF(_ sender: Any) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        
        if let type = vc.getSidebarType(), type == .Trash {
            vc.storageOutlineView.deselectAll(nil)
        }
        
        vc.createNote(type: .RichText)
    }
    
    @IBAction func moveMenu(_ sender: Any) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        
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
    
    @IBAction func fileName(_ sender: NSTextField) {
        let value = sender.stringValue
        
        guard let note = notesTableView.getNoteFromSelectedRow(), let url = note.url else {
            return
        }
        
        let newName = sender.stringValue + "." + note.url.pathExtension
        let isSoftRename = note.url.lastPathComponent.lowercased() == newName.lowercased()
        
        if let itemStorage = note.project, itemStorage.fileExist(fileName: value, ext: note.url.pathExtension), !isSoftRename {
            let alert = NSAlert()
            alert.messageText = "Hmm, something goes wrong 🙈"
            alert.informativeText = "Note with name \"\(value)\" already exists in selected storage."
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
        UserDataService.instance.lastRenamed = newUrl
        
        if note.url.path == newUrl.path {
            return
        }
        
        note.url = newUrl
        note.parseURL()
        
        do {
            try FileManager.default.moveItem(at: url, to: newUrl)
            print("File moved from \"\(url.deletingPathExtension().lastPathComponent)\" to \"\(newUrl.deletingPathExtension().lastPathComponent)\"")
        } catch {
            note.url = url
            note.parseURL()
        }
    }
    
    @IBAction func editorMenu(_ sender: Any) {
        external(selectedRow: notesTableView.selectedRow)
    }
    
    @IBAction func finderMenu(_ sender: Any) {
        finder(selectedRow: notesTableView.selectedRow)
    }
    
    @IBAction func makeMenu(_ sender: Any) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        
        if let type = vc.getSidebarType(), type == .Trash {
            vc.storageOutlineView.deselectAll(nil)
        }
        
        vc.createNote()
    }
    
    @IBAction func pinMenu(_ sender: Any) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        vc.pin(vc.notesTableView.selectedRowIndexes)
    }
    
    @IBAction func renameMenu(_ sender: Any) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        vc.renameNote(selectedRow: vc.notesTableView.clickedRow)
    }
        
    @IBAction func deleteNote(_ sender: Any) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        guard let notes = vc.notesTableView.getSelectedNotes() else {
            return
        }
        
        var isTrash = false
        if let sidebarItem = vc.getSidebarItem() {
            isTrash = sidebarItem.isTrash()
        }
        
        if isTrash {
            let alert = NSAlert()
            alert.messageText = String(format: NSLocalizedString("Are you sure you want to irretrievably delete %d note(s)?", comment: ""), notes.count)
            
            alert.informativeText = NSLocalizedString("This action cannot be undone.", comment: "")
            alert.addButton(withTitle: NSLocalizedString("Remove note(s)", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModal(for: vc.view.window!) { (returnCode: NSApplication.ModalResponse) -> Void in
                if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                    vc.editArea.clear()
                    vc.storage.removeNotes(notes: notes) { _ in
                        vc.storageOutlineView.reloadSidebar()
                        DispatchQueue.main.async {
                            vc.notesTableView.removeByNotes(notes: notes)
                        }
                    }
                }
            }
            
            return
        }
        
        let selectedRow = vc.notesTableView.selectedRow
        
        UserDataService.instance.searchTrigger = true
        vc.editArea.clear()
        vc.storage.removeNotes(notes: notes) { urls in
            vc.storageOutlineView.reloadSidebar()
            DispatchQueue.main.async {
                vc.notesTableView.removeByNotes(notes: notes)
                
                if
                    let appd = NSApplication.shared.delegate as? AppDelegate,
                    let md = appd.mainWindowController {
                    
                    let undoManager = md.notesListUndoManager
                    undoManager.registerUndo(withTarget: vc.notesTableView, selector: #selector(vc.notesTableView.unDelete), object: urls)
                    undoManager.setActionName(NSLocalizedString("Delete", comment: ""))
                    
                    if selectedRow > -1 {
                        vc.notesTableView.selectRow(selectedRow)
                        UserDataService.instance.skipListReload = true
                    }
                    
                    UserDataService.instance.searchTrigger = false
                }
            }
        }
    }
    
    @IBAction func archiveNote(_ sender: Any) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        
        guard let notes = vc.notesTableView.getSelectedNotes() else {
            return
        }
        
        if let project = storage.getArchive() {
            for note in notes {
                let removed = note.removeAllTags()
                vc.storageOutlineView.removeTags(removed)
            }
            
            move(notes: notes, project: project)
        }
    }

    @IBAction func tagNote(_ sender: Any) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        guard let notes = vc.notesTableView.getSelectedNotes() else { return }
        guard let note = notes.first else { return }
        
        let window = NSApp.windows[0]
        vc.alert = NSAlert()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
        field.placeholderString = "sex, drugs, rock and roll"
        field.stringValue = note.getCommaSeparatedTags()
        
        vc.alert?.messageText = NSLocalizedString("Tags", comment: "Menu")
        vc.alert?.informativeText = NSLocalizedString("Please enter tags (comma separated):", comment: "Menu")
        vc.alert?.accessoryView = field
        vc.alert?.alertStyle = .informational
        vc.alert?.addButton(withTitle: "OK")
        vc.alert?.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                if let tags = TagList(tags: field.stringValue).get() {
                    var removed = [String]()
                    var deselected = [String]()
                    
                    for note in notes {
                        let r = note.saveTags(tags)
                        removed = r.0
                        deselected = r.1
                    }
                    
                    vc.storageOutlineView.removeTags(removed)
                    vc.storageOutlineView.deselectTags(deselected)
                    vc.storageOutlineView.addTags(tags)
                }
            }
            
            vc.alert = nil
        }
        
        field.becomeFirstResponder()
    }
    
    @IBAction func openInExternalEditor(_ sender: Any) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        vc.external(selectedRow: vc.notesTableView.selectedRow)
    }
    
    @IBAction func revealInFinder(_ sender: Any) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        vc.finder(selectedRow: vc.notesTableView.selectedRow)
    }
    
    @IBAction func toggleNoteList(_ sender: Any) {
        guard let vc = NSApplication.shared.windows.first?.contentViewController as? ViewController else { return }
        
        if !UserDefaultsManagement.hideSidebar {
            UserDefaultsManagement.hideSidebar = true
            vc.splitView.subviews[0].isHidden = true
            return
        }

        vc.splitView.subviews[0].isHidden = false
        UserDefaultsManagement.hideSidebar = false
    }
    
    @IBAction func toggleSidebar(_ sender: Any) {
        guard let vc = NSApplication.shared.windows.first?.contentViewController as? ViewController else { return }
        
        if !UserDefaultsManagement.hideRealSidebar {
            if vc.sidebarSplitView.subviews[0].frame.width != 0.0 {
                UserDefaultsManagement.realSidebarSize = Int(vc.sidebarSplitView.subviews[0].frame.width)
            }
            
            UserDefaultsManagement.hideRealSidebar = true
            vc.sidebarSplitView.setPosition(0, ofDividerAt: 0)
            vc.searchTopConstraint.constant = CGFloat(25)
        } else {
            let size =
                UserDefaultsManagement.realSidebarSize > 10
                    ? UserDefaultsManagement.realSidebarSize
                    : 200
            
            vc.sidebarSplitView.setPosition(CGFloat(size), ofDividerAt: 0)
            UserDefaultsManagement.hideRealSidebar = false
            UserDefaultsManagement.realSidebarSize = size
            vc.searchTopConstraint.constant = CGFloat(8)
        }
    }
    
    @IBAction func emptyTrash(_ sender: NSMenuItem) {
        guard let vc = NSApplication.shared.windows.first?.contentViewController as? ViewController else { return }
        
        if let sidebarItem = vc.getSidebarItem(), sidebarItem.isTrash() {
            let indexSet = IndexSet(integersIn: 0..<vc.notesTableView.noteList.count)
            vc.notesTableView.removeRows(at: indexSet, withAnimation: .effectFade)
        }
        
        let notes = storage.getAllTrash()
        for note in notes {
            _ = note.removeFile()
        }
        
        NSSound(named: NSSound.Name(rawValue: "Pop"))?.play()
    }
    
    @IBAction func printNotes(_ sender: NSMenuItem) {
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
    
    // Changed main edit view
    func textDidChange(_ notification: Notification) {
        timer.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(enableFSUpdates), userInfo: nil, repeats: false)

        UserDataService.instance.fsUpdatesDisabled = true
        let index = notesTableView.selectedRow
        
        if (
            notesTableView.noteList.indices.contains(index)
            && index > -1
            && !UserDefaultsManagement.preview
        ) {
            editArea.removeHighlight()
            let note = notesTableView.noteList[index]
            
            note.content = NSMutableAttributedString(attributedString: editArea.attributedString())
            note.save()
            storage.add(note)
            
            if UserDefaultsManagement.sort == .modificationDate && UserDefaultsManagement.sortDirection == true {
                moveNoteToTop(note: index)
            }
        }
    }
    
    @objc func enableFSUpdates() {
        UserDataService.instance.fsUpdatesDisabled = false
    }
    
    func getSidebarProject() -> Project? {
        let sidebarItem = storageOutlineView.item(atRow: storageOutlineView.selectedRow) as? SidebarItem
        
        if let project = sidebarItem?.project {
            return project
        }
        
        return nil
    }
    
    func getSidebarType() -> SidebarItemType? {
        let sidebarItem = storageOutlineView.item(atRow: storageOutlineView.selectedRow) as? SidebarItem
        
        if let type = sidebarItem?.type {
            return type
        }
        
        return nil
    }
    
    func getSidebarItem() -> SidebarItem? {
        if let sidebarItem = storageOutlineView.item(atRow: storageOutlineView.selectedRow) as? SidebarItem {
        
            return sidebarItem
        }
        
        return nil
    }
    

    
    func updateTable(search: Bool = false, completion: @escaping () -> Void = {}) {
        self.searchQueue.cancelAllOperations()
        
        let filter = self.search.stringValue.lowercased()
        let sidebarName = self.getSidebarItem()?.name ?? ""
        let selectedProject = self.getSidebarProject()
        let type = self.getSidebarType()
        
        let operation = BlockOperation()
        operation.addExecutionBlock {
            
            var terms = filter.split(separator: " ")
            let source = self.storage.noteList
            var notes = [Note]()
            
            if let type = type, type == .Todo {
                terms.append("- [ ]")
                terms.append("- [x]")
            }
            
            for note in source {
                if operation.isCancelled {
                    break
                }
                
                if (!note.name.isEmpty
                        && (
                            filter.isEmpty && type != .Todo
                                || self.isMatched(note: note, terms: terms)
                        ) && (
                            type == .All && note.project != nil && !note.project!.isArchive
                                || type == .Tag && note.tagNames.contains(sidebarName)
                                || [.Category, .Label].contains(type) && selectedProject != nil && note.project == selectedProject
                                || type == nil && selectedProject == nil && note.project != nil && !note.project!.isArchive
                                || selectedProject != nil && selectedProject!.isRoot && note.project?.parent == selectedProject
                                || type == .Trash
                                || type == .Todo
                                || type == .Archive && note.project != nil && note.project!.isArchive
                        ) && (
                            type == .Trash && note.isTrash()
                                || type != .Trash && !note.isTrash()
                    )
                ) {
                    notes.append(note)
                }
            }

            self.notesTableView.noteList = self.storage.sortNotes(noteList: notes, filter: filter, operation: operation)
            
            if operation.isCancelled {
                completion()
                return
            }
            
            DispatchQueue.main.async {
                self.notesTableView.reloadData()
                
                if search {
                    if (self.notesTableView.noteList.count > 0) {
                        let note = self.notesTableView.noteList[0]
                        
                        if UserDefaultsManagement.textMatchAutoSelection || note.title.lowercased().starts(with: filter){
                            self.selectNullTableRow()
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
    
    private func isMatched(note: Note, terms: [Substring]) -> Bool {
        for term in terms {
            if note.name.range(of: term, options: .caseInsensitive, range: nil, locale: nil) != nil || note.content.string.range(of: term, options: .caseInsensitive, range: nil, locale: nil) != nil {
                continue
            }
            
            return false
        }
        
        return true
    }
    
    @objc func selectNullTableRow() {
        notesTableView.selectRowIndexes([0], byExtendingSelection: false)
        notesTableView.scrollRowToVisible(0)
    }
    
    func focusEditArea(firstResponder: NSResponder? = nil) {
        var resp: NSResponder = self.editArea
        if let responder = firstResponder {
            resp = responder
        }
        
        if (self.notesTableView.selectedRow > -1) {
            DispatchQueue.main.async() {
                self.editArea.isEditable = true
                self.emptyEditAreaImage.isHidden = true
                self.editArea.window?.makeFirstResponder(resp)
                
                if UserDefaultsManagement.focusInEditorOnNoteSelect {
                    self.editArea.restoreCursorPosition()
                }
            }
            return
        }
        
        editArea.window?.makeFirstResponder(resp)
    }
    
    func focusTable() {
        DispatchQueue.main.async {
            let index = self.notesTableView.selectedRow > -1 ? self.notesTableView.selectedRow : 0
            
            self.notesTableView.window?.makeFirstResponder(self.notesTableView)
            self.notesTableView.selectRowIndexes([index], byExtendingSelection: false)
            self.notesTableView.scrollRowToVisible(index)
        }
    }
    
    func cleanSearchAndEditArea() {
        search.becomeFirstResponder()
        notesTableView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
        search.stringValue = ""
        editArea.clear()
        updateTable()
    }
    
    func makeNoteShortcut() {
        let clipboard = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string)
        if (clipboard != nil) {
            createNote(content: clipboard!)
            
            let notification = NSUserNotification()
            notification.title = "FSNotes"
            notification.informativeText = "Clipboard successfully saved"
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
    
    func searchShortcut() {
        guard let mainWindow = NSApplication.shared.windows.first else { return }

        if (
            NSApplication.shared.isActive
            && !NSApplication.shared.isHidden
            && !mainWindow.isMiniaturized
        ) {
            NSApplication.shared.hide(nil)
            return
        }
                
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
        notesTableView.moveRow(at: index, to: position)
        notesTableView.reloadData(forRowIndexes: [index, position], columnIndexes: [0])
        notesTableView.scrollRowToVisible(0)
    }
    
    func createNote(name: String = "", content: String = "", type: NoteType? = nil) {
        guard let vc = NSApp.windows[0].contentViewController as? ViewController else { return }
        
        var sidebarProject = getSidebarProject()
        var text = content
        
        if let type = vc.getSidebarType(), type == .Todo, content.count == 0 {
            text = "- [ ] "
        }
        
        if sidebarProject == nil {
            let projects = storage.getProjects()
            sidebarProject = projects.first
        }
        
        guard let project = sidebarProject else {
            return
        }
                
        disablePreview()
        editArea.string = text
        
        let note = Note(name: name, project: project, type: type)
        note.content = NSMutableAttributedString(string: text)
        note.isCached = true
        note.save()
        
        if let si = getSidebarItem(), si.type == .Tag {
            note.addTag(si.name)
        }
        
        note.markdownCache()
        refillEditArea()
        
        self.search.stringValue.removeAll()
        updateTable() {
            DispatchQueue.main.async {
                if let index = self.notesTableView.getIndex(note) {
                    self.notesTableView.selectRowIndexes([index], byExtendingSelection: false)
                    self.notesTableView.scrollRowToVisible(index)
                }
            
                self.focusEditArea()
            }
        }
    }
    
    func pin(_ selectedRows: IndexSet) {
        guard !selectedRows.isEmpty, let notes = filteredNoteList, var state = filteredNoteList else { return }

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

        let resorted = storage.sortNotes(noteList: notes, filter: self.search.stringValue)
        let indexes = updatedNotes.compactMap({ _, note in resorted.index(of: note) })
        let newIndexes = IndexSet(indexes)

        notesTableView.beginUpdates()
        let nowPinned = updatedNotes.filter { _, note in note.isPinned }
        for (row, note) in nowPinned {
            guard let newRow = resorted.index(of: note) else { continue }
            notesTableView.moveRow(at: row, to: newRow)
            print("move \(row) to \(newRow)")
            let toMove = state.remove(at: row)
            state.insert(toMove, at: newRow)
        }

        print("state \(state)")
        let nowUnpinned = updatedNotes
            .filter({ (_, note) -> Bool in !note.isPinned })
            .compactMap({ (_, note) -> (Int, Note)? in
                guard let curRow = state.index(of: note) else { return nil }
                return (curRow, note)
            })
        for (row, note) in nowUnpinned.reversed() {
            guard let newRow = resorted.index(of: note) else { continue }
            print("move \(row) to \(newRow)")
            notesTableView.moveRow(at: row, to: newRow)
            let toMove = state.remove(at: row)
            state.insert(toMove, at: newRow)
        }
        print("poststate \(state)")

        print("to reload: \(indexes)")
        notesTableView.noteList = resorted
        notesTableView.reloadData(forRowIndexes: newIndexes, columnIndexes: [0])
        notesTableView.selectRowIndexes(newIndexes, byExtendingSelection: false)
        notesTableView.endUpdates()

        filteredNoteList = resorted
    }
        
    func renameNote(selectedRow: Int) {
        if (!notesTableView.noteList.indices.contains(selectedRow)) {
            return
        }
        
        let row = notesTableView.rowView(atRow: selectedRow, makeIfNecessary: false) as! NoteRowView
        let cell = row.view(atColumn: 0) as! NoteCellView
        let note = cell.objectValue as! Note
        
        cell.name.isEditable = true
        cell.name.becomeFirstResponder()
        cell.name.stringValue = note.getTitleWithoutLabel()
        
        let fileName = cell.name.currentEditor()!.string as NSString
        let fileNameLength = fileName.length
        
        cell.name.currentEditor()?.selectedRange = NSMakeRange(0, fileNameLength)
    }
    
    func finder(selectedRow: Int) {
        if (self.notesTableView.noteList.indices.contains(selectedRow)) {
            let note = notesTableView.noteList[selectedRow]
            NSWorkspace.shared.activateFileViewerSelecting([note.url])
        }
    }
    
    func external(selectedRow: Int) {
        if (notesTableView.noteList.indices.contains(selectedRow)) {
            let note = notesTableView.noteList[selectedRow]
            
            NSWorkspace.shared.openFile(note.url.path, withApplication: UserDefaultsManagement.externalEditor)
        }
    }
        
    func enablePreview() {
        let vc = NSApplication.shared.windows.first!.contentViewController as! ViewController
        vc.editArea.window?.makeFirstResponder(vc.notesTableView)
        
        self.view.window!.title = NSLocalizedString("FSNotes [preview]", comment: "")
        UserDefaultsManagement.preview = true
        refillEditArea()
    }
    
    func disablePreview() {
        self.view.window!.title = NSLocalizedString("FSNotes [edit]", comment: "")
        UserDefaultsManagement.preview = false
        refillEditArea()
    }
    
    func togglePreview() {
        if (UserDefaultsManagement.preview) {
            disablePreview()
        } else {
            enablePreview()
        }
    }
    
    func loadMoveMenu() {
        guard
            let vc = NSApp.windows[0].contentViewController as? ViewController,
            let note = vc.notesTableView.getSelectedNote(),
            let project = note.project else { return }
        
        let moveTitle = NSLocalizedString("Move", comment: "Menu")
        if let prevMenu = noteMenu.item(withTitle: moveTitle) {
            noteMenu.removeItem(prevMenu)
        }
        
        let moveMenuItem = NSMenuItem()
        moveMenuItem.title = NSLocalizedString("Move", comment: "Menu")
        
        noteMenu.addItem(moveMenuItem)
        let moveMenu = NSMenu()
        
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
            moveMenu.addItem(trashMenu)
            moveMenu.addItem(NSMenuItem.separator())
        }
                
        let projects = storage.getProjects()
        for item in projects {
            if project == item || item.isTrash || item.isArchive {
                continue
            }
            
            let menuItem = NSMenuItem()
            menuItem.title = item.getFullLabel()
            menuItem.representedObject = item
            menuItem.action = #selector(vc.moveNote(_:))
            moveMenu.addItem(menuItem)
        }
        
        noteMenu.setSubmenu(moveMenu, for: moveMenuItem)
    }

    func loadSortBySetting() {
        let viewLabel = NSLocalizedString("View", comment: "Menu")
        let sortByLabel = NSLocalizedString("Sort By", comment: "View menu")
        
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
            if let id = item.identifier, id.rawValue ==  sort.rawValue {
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
            let keyStore = NSUbiquitousKeyValueStore()
            for key in keys {
                if let isPinned = keyStore.object(forKey: key) as? Bool, let note = storage.getBy(name: key) {
                    note.isPinned = isPinned
                }
            }
            
            DispatchQueue.main.async {
                self.reloadView()
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
    
    @IBAction func duplicate(_ sender: Any) {
        if let note = notesTableView.getSelectedNote() {
            let newNote = note.duplicateNote()
            self.notesTableView.insertNew(note: newNote)
        }
    }
    
    @IBAction func copyURL(_ sender: Any) {
        if let note = notesTableView.getSelectedNote(), let title = note.title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {

            let name = "fsnotes://find/\(title)"
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
    
    //MARK: Share Service
    
    @IBAction func shareSheet(_ sender: NSButton) {
        if let note = notesTableView.getSelectedNote() {
            let sharingPicker = NSSharingServicePicker(items: [note.content])
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
            guard let render = try? note.content.string.toHTML() else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(render, forType: NSPasteboard.PasteboardType.string)
        }
    }
    
}

