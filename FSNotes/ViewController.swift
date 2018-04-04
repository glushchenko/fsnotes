//
//  ViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/20/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import MASShortcut
import CoreData

class ViewController: NSViewController,
    NSTextViewDelegate,
    NSTextFieldDelegate,
    NSSplitViewDelegate {
    
    var lastSelectedNote: Note?
    var filteredNoteList: [Note]?
    var prevQuery: String?
    let storage = Storage.sharedInstance()
    
    @IBOutlet var emptyEditAreaImage: NSImageView!
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var searchWrapper: NSTextField!
    @IBOutlet var editArea: EditTextView!
    @IBOutlet weak var editAreaScroll: NSScrollView!
    @IBOutlet weak var search: SearchTextField!
    @IBOutlet weak var notesTableView: NotesTableView!
    
    @IBOutlet var noteMenu: NSMenu!
    
    override func viewDidAppear() {
        self.view.window!.title = "FSNotes"
        self.view.window!.titlebarAppearsTransparent = true
        
        // autosave size and position
        self.view.window?.setFrameAutosaveName(NSWindow.FrameAutosaveName(rawValue: "MainWindow"))
        splitView.autosaveName = NSSplitView.AutosaveName(rawValue: "SplitView")
        
        // editarea paddings
        editArea.textContainerInset.height = 10
        editArea.textContainerInset.width = 5
        editArea.isEditable = false
        
        if (UserDefaultsManagement.horizontalOrientation) {
            self.splitView.isVertical = false
        }
        
        setTableRowHeight()
                
        super.viewDidAppear()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let bookmark = SandboxBookmark()
        bookmark.load()
        
        editArea.delegate = self
        search.delegate = self
        splitView.delegate = self
        
        if CoreDataManager.instance.getBy(label: "general") == nil {
            let context = CoreDataManager.instance.context
            let storage = StorageItem(context: context)
            storage.path = UserDefaultsManagement.storageUrl.absoluteString
            storage.label = "general"
            CoreDataManager.instance.save()
        }
        
        watchFSEvents()
        
        if storage.noteList.count == 0 {
            storage.loadDocuments()
            updateTable(filter: "") {
                if let url = UserDefaultsManagement.lastSelectedURL, let lastNote = self.storage.getBy(url: url), let i = self.notesTableView.getIndex(lastNote) {
                    self.notesTableView.selectRow(i)
                }
            }
        }
        
        let font = UserDefaultsManagement.noteFont
        editArea.font = font
        
        // Global shortcuts monitoring
        MASShortcutMonitor.shared().register(UserDefaultsManagement.newNoteShortcut, withAction: {
            self.makeNoteShortcut()
        })
        
        MASShortcutMonitor.shared().register(UserDefaultsManagement.searchNoteShortcut, withAction: {
            self.searchShortcut()
        })
        
        // Local shortcuts monitoring
        NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged) {
            return $0
        }
        
        NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown) {
            self.keyDown(with: $0)
            return $0
        }
                
        loadMoveMenu()
        loadSortBySetting()
        
        #if CLOUDKIT
            keyValueWatcher()
        #endif
    }
    
    @IBOutlet weak var sortByOutlet: NSMenuItem!
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
            
            if let list = storage.sortNotes(noteList: storage.noteList) {
                storage.noteList = list
                viewController.notesTableView.noteList = list
                viewController.notesTableView.reloadData()
            }
        }
    }
    
    @IBAction func fileMenuNewNote(_ sender: Any) {
        createNote()
    }
    
    @IBAction func fileMenuNewRTF(_ sender: Any) {
        createNote(type: .RichText)
    }
    
    @objc func moveNote(_ sender: NSMenuItem) {
        let storageItem = sender.representedObject as! StorageItem
        
        guard let notes = notesTableView.getSelectedNotes(), let url = storageItem.getUrl() else {
            return
        }
        
        for note in notes {
            let destination = url.appendingPathComponent(note.name)
            do {
                try FileManager.default.moveItem(at: note.url, to: destination)
            } catch {
                let alert = NSAlert.init()
                alert.messageText = "Hmm, something goes wrong 🙈"
                alert.informativeText = "Note with name \(note.name) already exist in selected storage."
                alert.runModal()
            }
        }
    }
        
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return splitView.frame.width / 2
    }
    
    var refilled: Bool = false
    func splitViewDidResizeSubviews(_ notification: Notification) {
        if !refilled {
            self.refilled = true
            DispatchQueue.main.async() {
                self.refillEditArea(previewOnly: true)
                self.refilled = false
            }
        }
    }
    
    func watchFSEvents() {
        var pathList: [String] = []
        
        let storageItemList = CoreDataManager.instance.fetchStorageList()
        for storageItem in storageItemList {
            if let path = storageItem.getUrl()?.path {
                pathList.append(NSString(string: path).expandingTildeInPath)
            }
        }
        
        let filewatcher = FileWatcher(pathList)
        filewatcher.callback = { event in
            if UserDataService.instance.fsUpdatesDisabled {
                return
            }
            
            guard let path = event.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                return
            }
            
            guard let url = URL(string: "file://" + path) else {
                return
            }
            
            if event.fileRenamed {
                let note = self.storage.getBy(url: url)
                let fileExistInFS = self.checkFile(url: url, pathList: pathList)

                if note != nil {
                    if fileExistInFS {
                        self.watcherCreateTrigger(url)
                    } else {
                        guard let unwrappedNote = note else {
                            return
                        }
                        
                        print("FSWatcher remove note: \"\(unwrappedNote.name)\"")
                        
                        self.storage.removeNotes(notes: [unwrappedNote], fsRemove: false) {
                            DispatchQueue.main.async {
                                self.notesTableView.removeByNotes(notes: [unwrappedNote])
                            }
                        }
                    }
                } else if fileExistInFS {
                    self.watcherCreateTrigger(url)
                }
                
                return
            }
            
            guard self.checkFile(url: url, pathList: pathList) else {
                return
            }
            
            if event.fileChange {
                let wrappedNote = self.storage.getBy(url: url)
                
                if let note = wrappedNote, note.reload() {
                    note.markdownCache()
                    self.refillEditArea()
                } else {
                    self.watcherCreateTrigger(url)
                }
                return
            }
            
            if event.fileCreated {
                self.watcherCreateTrigger(url)
            }
        }
        filewatcher.start()
    }
    
    func watcherCreateTrigger(_ url: URL) {
        let n = storage.getBy(url: url)
        
        guard n == nil else {
            if let nUnwrapped = n, nUnwrapped.url == UserDataService.instance.lastRenamed {
                self.updateTable(filter: "") {
                    self.notesTableView.setSelected(note: nUnwrapped)
                    UserDataService.instance.lastRenamed = nil
                }
            }
            return
        }
        
        var note: Note
        if let existNote = CoreDataManager.instance.getBy(url: url) {
            note = existNote
        } else {
            note = CoreDataManager.instance.make()
        }
        
        note.storage = CoreDataManager.instance.fetchStorageItemBy(fileUrl: url)
        note.load(url)
        note.loadModifiedLocalAt()
        note.markdownCache()
        refillEditArea()
        
        print("FSWatcher import note: \"\(note.name)\"")
        storage.saveNote(note: note)
        
        DispatchQueue.main.async {
            if let url = UserDataService.instance.lastRenamed,
                let note = self.storage.getBy(url: url) {
                self.updateTable(filter: "") {
                    self.notesTableView.setSelected(note: note)
                    UserDataService.instance.lastRenamed = nil
                }
            } else {
                self.reloadView(note: note)
            }
        }
        
        if note.name == "FSNotes - Readme.md" {
            updateTable(filter: "") {
                self.notesTableView.selectRow(0)
                note.addPin()
            }
        }
    }
    
    func checkFile(url: URL, pathList: [String]) -> Bool {
        return (
            FileManager.default.fileExists(atPath: url.path)
            && storage.allowedExtensions.contains(url.pathExtension)
            && pathList.contains(url.deletingLastPathComponent().path)
        )
    }
    
    func reloadView(note: Note? = nil) {
        let notesTable = self.notesTableView!
        let selectedNote = notesTable.getSelectedNote()
        let cursor = editArea.selectedRanges[0].rangeValue.location
        
        self.updateTable(filter: self.search.stringValue) {
            if let selected = selectedNote, let index = notesTable.getIndex(selected) {
                notesTable.selectRowIndexes([index], byExtendingSelection: false)
                self.refillEditArea(cursor: cursor)
            }
        }
    }
    
    func setTableRowHeight() {
        notesTableView.rowHeight = CGFloat(16 + UserDefaultsManagement.cellSpacing)
    }
    
    func refillEditArea(cursor: Int? = nil, previewOnly: Bool = false) {
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
                if let note = self.notesTableView.getSelectedNote(){
                    self.editArea.fill(note: note)
                }
            }
            
            self.editArea.setSelectedRange(NSRange.init(location: location, length: 0))
        }
    }
        
    override func keyDown(with event: NSEvent) {
        
        // Control + Tab
        if event.keyCode == kVK_Tab && event.modifierFlags.contains(.control) {
            self.notesTableView.window?.makeFirstResponder(self.notesTableView)
            return
        }
        
        // Focus search bar on ESC
        if (event.keyCode == 53) {
            cleanSearchAndEditArea()
        }
        
        // Focus search field shortcut (cmd-L)
        if (event.keyCode == 37 && event.modifierFlags.contains(.command)) {
            search.becomeFirstResponder()
        }
        
        // Remove note (cmd-delete)
        if (event.keyCode == 51 && event.modifierFlags.contains(.command)) {
            let focusOnEditArea = (editArea.window?.firstResponder?.isKind(of: EditTextView.self))!
            
            if !focusOnEditArea || event.modifierFlags.contains(.shift) {
                deleteNotes(notesTableView.selectedRowIndexes)
            }
        }
        
        // Note edit mode and select file name (cmd-r)
        if (
            event.keyCode == 15
            && event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.shift)
        ) {
            renameNote(selectedRow: notesTableView.selectedRow)
        }
        
        // Make note shortcut (cmd-n)
        if (
            event.keyCode == 45
            && event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.shift)
        ) {
            makeNote(NSTextField())
        }
        
        // Make note shortcut (cmd-n)
        if (
            event.keyCode == 45
            && event.modifierFlags.contains(.command)
            && event.modifierFlags.contains(.shift)
        ) {
            fileMenuNewRTF(NSTextField())
        }
        
        // Pin note shortcut (cmd-8)
        if (event.keyCode == 28 && event.modifierFlags.contains(.command)) {
            pin(notesTableView.selectedRowIndexes)
        }
        
        // Next note (cmd-j)
        if (event.keyCode == 38 && event.modifierFlags.contains(.command)) {
            notesTableView.selectNext()
        }
        
        // Prev note (cmd-k)
        if (event.keyCode == 40 && event.modifierFlags.contains(.command)) {
            notesTableView.selectPrev()
        }
                
        // Open in external editor (cmd-control-e)
        if (
            event.keyCode == 14
            && event.modifierFlags.contains(.command)
            && event.modifierFlags.contains(.control)
        ) {
            external(selectedRow: notesTableView.selectedRow)
        }
        
        // Open in finder (cmd-shift-r)
        if (
            event.keyCode == 15
            && event.modifierFlags.contains(.command)
            && event.modifierFlags.contains(.shift)
        ) {
            finder(selectedRow: notesTableView.selectedRow)
        }
        
        // Open menu and focus move (cmd-shift-t)
        if (
            event.keyCode == kVK_ANSI_T
            && event.modifierFlags.contains(.command)
            && event.modifierFlags.contains(.shift)
        ) {
            if notesTableView.selectedRow >= 0  {
                let moveMenu = noteMenu.item(withTitle: "Move")
                let view = notesTableView.rect(ofRow: notesTableView.selectedRow)
                let x = splitView.subviews[0].frame.width + 5
                let general = moveMenu?.submenu?.item(at: 0)
                
                moveMenu?.submenu?.popUp(positioning: general, at: NSPoint(x: x, y: view.origin.y + 8), in: notesTableView)
            }
        }
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func makeNote(_ sender: NSTextField) {
        let value = sender.stringValue
        if (value.count > 0) {
            createNote(name: value)
        } else {
            createNote()
        }
    }
    
    @IBAction func fileName(_ sender: NSTextField) {
        let value = sender.stringValue
        
        guard let note = notesTableView.getNoteFromSelectedRow() else {
            return
        }
        
        let newName = sender.stringValue + "." + note.url.pathExtension
        let isSoftRename = note.url.lastPathComponent.lowercased() == newName.lowercased()
        
        if let itemStorage = note.storage, itemStorage.fileExist(fileName: value, ext: note.url.pathExtension), !isSoftRename {
            let alert = NSAlert()
            alert.messageText = "Hmm, something goes wrong 🙈"
            alert.informativeText = "Note with name \(value) already exist in selected storage."
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
        
        do {
            try FileManager.default.moveItem(at: note.url, to: newUrl)
            print("File moved from \"\(note.url.deletingPathExtension().lastPathComponent)\" to \"\(newUrl.deletingPathExtension().lastPathComponent)\"")
        } catch {}
        
        if isSoftRename {
            note.url = newUrl
            note.parseURL()
        }
        
        reloadView()
        sender.stringValue = note.title
        cleanSearchAndEditArea()
    }
    
    @IBAction func editorMenu(_ sender: Any) {
        external(selectedRow: notesTableView.selectedRow)
    }
    
    @IBAction func finderMenu(_ sender: Any) {
        finder(selectedRow: notesTableView.selectedRow)
    }
    
    @IBAction func makeMenu(_ sender: Any) {
        createNote()
    }
    
    @IBAction func pinMenu(_ sender: Any) {
        pin(notesTableView.selectedRowIndexes)
    }
    
    @IBAction func renameMenu(_ sender: Any) {
        renameNote(selectedRow: notesTableView.clickedRow)
    }
    
    @IBAction func deleteNote(_ sender: Any) {
        deleteNotes(notesTableView.selectedRowIndexes)
    }
    
    @IBAction func toggleNoteList(_ sender: Any) {
        if !UserDefaultsManagement.hideSidebar {
            UserDefaultsManagement.sidebarSize = Int(splitView.subviews[0].frame.width)
            UserDefaultsManagement.hideSidebar = true
            splitView.setPosition(0, ofDividerAt: 0)
            return
        }
        
        let size = UserDefaultsManagement.sidebarSize
        splitView.setPosition(CGFloat(size), ofDividerAt: 0)
        UserDefaultsManagement.hideSidebar = false
    }
    
    var timer = Timer()
    
    // Changed main edit view
    func textDidChange(_ notification: Notification) {
        timer.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(enableFSUpdates), userInfo: nil, repeats: false)

        UserDataService.instance.fsUpdatesDisabled = true
        let selected = notesTableView.selectedRow
        
        if (
            notesTableView.noteList.indices.contains(selected)
            && selected > -1
            && !UserDefaultsManagement.preview
        ) {
            editArea.removeHighlight()
            let note = notesTableView.noteList[selected]
            note.content = NSMutableAttributedString(attributedString: editArea.attributedString())
            note.save()
            storage.saveNote(note: note, userInitiated: true)
            
            if UserDefaultsManagement.sort == .ModificationDate && UserDefaultsManagement.sortDirection == true {
                moveAtTop(id: selected)
            }
        }
    }
    
    @objc func enableFSUpdates() {
        UserDataService.instance.fsUpdatesDisabled = false
    }
    
    // Changed search field
    override func controlTextDidChange(_ obj: Notification) {
        let value = self.search.stringValue
        
        UserDataService.instance.searchTrigger = true
        
        filterQueue.cancelAllOperations()
        filterQueue.addOperation {
            self.updateTable(filter: value, search: true) {}
        }
    }
    
    var filterQueue = OperationQueue.init()

    func updateTable(filter: String, search: Bool = false, completion: @escaping () -> Void) {
        if !search, let list = storage.sortNotes(noteList: storage.noteList) {
            storage.noteList = list
        }
        
        let searchTermsArray = filter.split(separator: " ")
        var source = storage.noteList
        
        if let query = prevQuery, filter.range(of: query) != nil, let unwrappedList = filteredNoteList {
            source = unwrappedList
        } else {
            prevQuery = nil
        }
        
        filteredNoteList =
            source.filter() {
                let searchContent = "\($0.name) \($0.content.string)"
                return (
                    !$0.name.isEmpty
                    && (
                        filter.isEmpty
                        || !searchTermsArray.contains(where: { !searchContent.localizedCaseInsensitiveContains($0)
                        })
                    )
                )
            }
        
        if let unwrappedList = filteredNoteList {
            notesTableView.noteList = unwrappedList
        }
        
        DispatchQueue.main.async {
            self.notesTableView.reloadData()
            
            if search {
                if (self.notesTableView.noteList.count > 0) {
                    self.selectNullTableRow()
                } else {
                    self.editArea.clear()
                }
            }
            
            completion()
        }
        
        prevQuery = filter
    }
        
    override func controlTextDidEndEditing(_ obj: Notification) {
        search.focusRingType = .none
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
        }
    }
    
    func focusTable() {
        DispatchQueue.main.async {
            let index = self.notesTableView.selectedRow > -1 ? 1 : 0
            
            self.notesTableView.window?.makeFirstResponder(self.notesTableView)
            self.notesTableView.selectRowIndexes([index], byExtendingSelection: false)
            self.notesTableView.scrollRowToVisible(0)
        }
    }
    
    func cleanSearchAndEditArea() {
        search.becomeFirstResponder()
        notesTableView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
        search.stringValue = ""
        editArea.clear()
        updateTable(filter: "") {}
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
        if (NSApplication.shared.isActive) {
            NSApplication.shared.hide(nil)
            return
        }
        
        UserDataService.instance.isShortcutCall = true
        
        let controller = NSApplication.shared.windows.first?.contentViewController as? ViewController
        controller?.focusEditArea(firstResponder: search)
        
        NSApp.activate(ignoringOtherApps: true)
        self.view.window?.makeKeyAndOrderFront(self)
    }
    
    func moveAtTop(id: Int) {
        let isPinned = notesTableView.noteList[id].isPinned
        let position = isPinned ? 0 : countVisiblePinned()
        let note = notesTableView.noteList.remove(at: id)

        notesTableView.noteList.insert(note, at: position)
        notesTableView.moveRow(at: id, to: position)
        notesTableView.reloadData(forRowIndexes: [id, position], columnIndexes: [0])
        notesTableView.scrollRowToVisible(0)
    }
    
    func createNote(name: String = "", content: String = "", type: NoteType? = nil) {
        disablePreview()
        editArea.string = content
        
        let note = CoreDataManager.instance.make()
        
        if let unwrappedType = type {
            note.type = unwrappedType
        } else {
            note.type = NoteType.withExt(rawValue: UserDefaultsManagement.storageExtension)
        }
        
        note.make(newName: name)
        note.content = NSMutableAttributedString(string: content)
        note.isSynced = false
        note.storage = CoreDataManager.instance.fetchGeneralStorage()
        note.isCached = true
        note.save()
        
        storage.saveNote(note: note, userInitiated: true)
        note.markdownCache()
        refillEditArea()
        
        updateTable(filter: "") {
            if let index = self.notesTableView.getIndex(note) {
                self.notesTableView.selectRowIndexes([index], byExtendingSelection: false)
                self.notesTableView.scrollRowToVisible(index)
            }
            
            self.focusEditArea()
            self.search.stringValue.removeAll()
        }
    }
    
    func pin(_ selectedRows: IndexSet) {
        guard !selectedRows.isEmpty else {
            return
        }
        
        for selectedRow in selectedRows {
            let row = notesTableView.rowView(atRow: selectedRow, makeIfNecessary: false) as! NoteRowView
            let cell = row.view(atColumn: 0) as! NoteCellView
            
            let note = cell.objectValue as! Note
            let selected = selectedRow
            
            note.togglePin()
            
            if selectedRows.count < 2 {
                moveAtTop(id: selected)
            }
            
            cell.renderPin()
        }
        
        if selectedRows.count > 1 {
            updateTable(filter: "") {}
        }
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
    
    func deleteNotes(_ selectedRows: IndexSet) {
        guard let notes = notesTableView.getSelectedNotes() else {
            return
        }
        
        let alert = NSAlert.init()
        alert.messageText = "Are you sure you want to move \(notes.count) note(s) to the trash?"
        alert.informativeText = "This action cannot be undone."
        alert.addButton(withTitle: "Remove note(s)")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: self.view.window!) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                self.editArea.clear()
                self.storage.removeNotes(notes: notes) {
                    DispatchQueue.main.async {
                        self.notesTableView.removeByNotes(notes: notes)
                    }
                }
            }
        }
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
    
    func countVisiblePinned() -> Int {
        var i = 0
        for note in notesTableView.noteList {
            if (note.isPinned) {
                i += 1
            }
        }
        return i
    }
    
    func enablePreview() {
        self.view.window!.title = "FSNotes [preview]"
        UserDefaultsManagement.preview = true
        refillEditArea()
    }
    
    func disablePreview() {
        self.view.window!.title = "FSNotes [edit]"
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
        let storageItemList = CoreDataManager.instance.fetchStorageList()
        
        if storageItemList.count > 1 {
            if let prevMenu = noteMenu.item(withTitle: "Move") {
                noteMenu.removeItem(prevMenu)
            }
            
            let moveMenuItem = NSMenuItem()
            moveMenuItem.title = "Move"
            noteMenu.addItem(moveMenuItem)
            
            let moveMenu = NSMenu()
            let label = NSMenuItem()
            label.title = "Storage:"
            let sep = NSMenuItem.separator()
            
            moveMenu.addItem(label)
            moveMenu.addItem(sep)
            
            for storageItem in storageItemList {
                guard let url = storageItem.getUrl() else {
                    return
                }
                
                var title = url.lastPathComponent
                if let label = storageItem.label {
                    title = label
                }
                
                let menuItem = NSMenuItem()
                menuItem.title = title
                menuItem.representedObject = storageItem
                menuItem.action = #selector(moveNote(_:))
                
                moveMenu.addItem(menuItem)
            }
            
            noteMenu.setSubmenu(moveMenu, for: moveMenuItem)
        }
    }

    func loadSortBySetting() {
        guard let menu = NSApp.menu, let view = menu.item(withTitle: "View"), let submenu = view.submenu, let sortMenu = submenu.item(withTitle: "Sort by"), let sortItems = sortMenu.submenu else {
            return
        }
        
        let sort = UserDefaultsManagement.sort
        
        for item in sortItems.items {
            if let id = item.identifier, id.rawValue ==  sort.rawValue {
                item.state = NSControl.StateValue.on
            }
        }
    }
    
    func keyValueWatcher() {
        let keyStore = NSUbiquitousKeyValueStore()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(
                                                ViewController.ubiquitousKeyValueStoreDidChange),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: keyStore)
        
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
}

