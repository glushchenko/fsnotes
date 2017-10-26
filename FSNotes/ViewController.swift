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
import CloudKit

class ViewController: NSViewController,
    NSTextViewDelegate,
    NSTextFieldDelegate {
    
    var lastSelectedNote: Note?
    let storage = Storage.instance
    
    @IBOutlet var emptyEditAreaImage: NSImageView!
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var searchWrapper: NSTextField!
    @IBOutlet var editArea: EditTextView!
    @IBOutlet weak var editAreaScroll: NSScrollView!
    @IBOutlet weak var search: SearchTextField!
    @IBOutlet weak var notesTableView: NotesTableView!
        
    override func viewDidAppear() {
        self.view.window!.title = "FSNotes"
        self.view.window!.titlebarAppearsTransparent = true
        
        // autosave size and position
        self.view.window?.setFrameAutosaveName("MainWindow")
        splitView.autosaveName = "SplitView"
        
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
        
        if storage.noteList.count == 0 {
            storage.loadDocuments()
            updateTable(filter: "")
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
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
            return $0
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            self.keyDown(with: $0)
            return $0
        }
        
        watchFSEvents()
        
        #if CLOUDKIT
            if UserDefaultsManagement.cloudKitSync {
                CloudKitManager.instance.verifyCloudKitSubscription()
            }
        #endif
    }
    
    func watchFSEvents() {
        let filewatcher = FileWatcher([NSString(string: UserDefaultsManagement.storagePath).expandingTildeInPath])
        filewatcher.callback = { event in
            guard let path = event.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                return
            }
            
            guard let url = URL(string: "file://" + path), self.checkFile(url) else {
                return
            }
            
            if event.modified {
                let wrappedNote = Storage.instance.getBy(url: url)
                if let note = wrappedNote, note.reload() {
                    self.refillEditArea()
                }
                return
            }
            
            if event.created {
                self.watcherCreateTrigger(url)
            }
        }
        filewatcher.start()
    }
    
    func watcherCreateTrigger(_ url: URL) {
        let coreDataNote = CoreDataManager.instance.getBy(url)
        let storageNote = Storage.instance.getBy(url: url)
        
        var note = coreDataNote
        let storageNoteExist = storageNote
        
        if note == nil {
            note = CoreDataManager.instance.make()
        }
        
        note!.load(url)
        CoreDataManager.instance.save()
        
        if storageNoteExist == nil {
            Storage.instance.add(note!)
        }
        
        reloadView(note: note!)
    }
    
    func checkFile(_ url: URL) -> Bool {
        return (
            FileManager.default.fileExists(atPath: url.path)
            && Storage.allowedExtensions.contains(url.pathExtension)
            && url.deletingLastPathComponent().path == UserDefaultsManagement.storageUrl.path
        )
    }
    
    func reloadView(note: Note) {
        let notesTable = self.notesTableView!
        let selectedNote = notesTable.getSelectedNote()
        let cursor = editArea.selectedRanges[0].rangeValue.location
        
        self.updateTable(filter: search.stringValue)
        notesTable.reloadData()
        
        if let selected = selectedNote, let index = notesTable.getIndex(selected) {
            notesTable.selectRowIndexes([index], byExtendingSelection: false)
            if selected == note {
                self.refillEditArea(cursor: cursor)
            }
        }
    }
    
    func setTableRowHeight() {
        notesTableView.rowHeight = CGFloat(UserDefaultsManagement.minTableRowHeight + UserDefaultsManagement.cellSpacing)
    }
    
    func refillEditArea(cursor: Int? = nil) {
        var location: Int = 0
        
        if let unwrappedCursor = cursor {
            location = unwrappedCursor
        } else {
            location = editArea.selectedRanges[0].rangeValue.location
        }
        
        let selected = notesTableView.selectedRow
        if (selected > -1 && notesTableView.noteList.indices.contains(selected)) {
            editArea.fill(note: notesTableView.noteList[notesTableView.selectedRow])
        }
        
        editArea.setSelectedRange(NSRange.init(location: location, length: 0))
    }
        
    override func keyDown(with event: NSEvent) {
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
            
            if !focusOnEditArea {
                deleteNote(selectedRow: notesTableView.selectedRow)
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
        if (event.keyCode == 45 && event.modifierFlags.contains(.command)) {
            makeNote(NSTextField())
        }
        
        // Pin note shortcut (cmd-y)
        if (event.keyCode == 28 && event.modifierFlags.contains(.command)) {
            pin(selectedRow: notesTableView.selectedRow)
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
    }
        
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func makeNote(_ sender: NSTextField) {
        let value = sender.stringValue
        if (value.characters.count > 0) {
            createNote(name: value)
        } else {
            createNote()
        }
    }
    
    @IBAction func fileName(_ sender: NSTextField) {
        guard let note = notesTableView.getNoteFromSelectedRow() else {
            return
        }
        
        sender.isEditable = false
        
        if (!note.rename(newName: sender.stringValue)) {
            Swift.print("Error: rename")
        }
        
        sender.stringValue = note.title
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
        pin(selectedRow: notesTableView.clickedRow)
    }
    
    @IBAction func renameMenu(_ sender: Any) {
        renameNote(selectedRow: notesTableView.clickedRow)
    }
    
    @IBAction func deleteNote(_ sender: Any) {
        deleteNote(selectedRow: notesTableView.clickedRow)
    }
    
    // Changed main edit view
    func textDidChange(_ notification: Notification) {
        let selected = notesTableView.selectedRow
        
        if (
            notesTableView.noteList.indices.contains(selected)
            && selected > -1
            && !UserDefaultsManagement.preview
        ) {
            editArea.removeHighlight()
            let content = editArea.string!
            let note = notesTableView.noteList[selected]
            note.content = content
            note.save(editArea.textStorage!)
            moveAtTop(id: selected)
        }
    }
    
    // Changed search field
    override func controlTextDidChange(_ obj: Notification) {
        notesTableView.noteList.removeAll();
        self.updateTable(filter: search.stringValue)
        
        if (notesTableView.noteList.count > 0) {
            editArea.fill(note: notesTableView.noteList[0], highlight: true)
            self.selectNullTableRow()
        } else {
            editArea.clear()
        }
    }
    
    func updateTable(filter: String) {
        let searchTermsArray = filter.split(separator: " ")
        
        notesTableView.noteList =
            storage.noteList.filter() {
                let searchContent = "\($0.name) \($0.content)"
                return (
                    !$0.name.isEmpty
                    && $0.isRemoved == false
                    && (
                        filter.isEmpty
                        || (
                            searchContent.localizedCaseInsensitiveContainsTerms(searchTermsArray)
                        )
                    )
                )
            }
            .sorted(by: {
                if $0.isPinned == $1.isPinned {
                    return $0.modifiedLocalAt! > $1.modifiedLocalAt!
                }
                return $0.isPinned && !$1.isPinned
            })
        
            notesTableView.reloadData()
    }
        
    override func controlTextDidEndEditing(_ obj: Notification) {
        search.focusRingType = .none
    }
    
    func selectNullTableRow() {
        notesTableView.selectRowIndexes([0], byExtendingSelection: false)
        notesTableView.scrollRowToVisible(0)
    }
    
    func focusEditArea() {
        if (self.notesTableView.selectedRow > -1) {
            DispatchQueue.main.async() {
                self.editArea.isEditable = true
                self.emptyEditAreaImage.isHidden = true
                self.editArea.window?.makeFirstResponder(self.editArea)
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
        updateTable(filter: "")
    }
    
    func makeNoteShortcut() {
        let clipboard = NSPasteboard.general().string(forType: NSPasteboardTypeString)
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
        NSApp.activate(ignoringOtherApps: true)
        self.view.window?.makeKeyAndOrderFront(self)
        
        search.becomeFirstResponder()
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
    
    func createNote(name: String = "", content: String = "") {
        disablePreview()
        editArea.string = content
        
        let note = CoreDataManager.instance.make()
        let nextId = storage.getNextId()
        note.make(id: nextId, newName: name)
        note.content = content
        note.isSynced = false
        note.type = UserDefaultsManagement.storageExtension
        
        let textStorage = NSTextStorage(attributedString: NSAttributedString(string: content))
        note.save(textStorage)
        
        updateTable(filter: "")
        notesTableView.selectRowIndexes([Storage.pinned], byExtendingSelection: false)
        notesTableView.scrollRowToVisible(Storage.pinned)
        focusEditArea()
        search.stringValue.removeAll()
    }
    
    func pin(selectedRow: Int) {
        let row = notesTableView.rowView(atRow: selectedRow, makeIfNecessary: false) as! NoteRowView
        let cell = row.view(atColumn: 0) as! NoteCellView
        
        let note = cell.objectValue as! Note
        let selected = selectedRow
        
        note.togglePin()
        moveAtTop(id: selected)
        cell.renderPin()
    }
        
    func renameNote(selectedRow: Int) {
        if (!notesTableView.noteList.indices.contains(selectedRow)) {
            return
        }
        
        let row = notesTableView.rowView(atRow: selectedRow, makeIfNecessary: false) as! NoteRowView
        let cell = row.view(atColumn: 0) as! NoteCellView
        
        cell.name.isEditable = true
        cell.name.becomeFirstResponder()
        
        let fileName = cell.name.currentEditor()!.string! as NSString
        let fileNameLength = fileName.length
        
        cell.name.currentEditor()?.selectedRange = NSMakeRange(0, fileNameLength)
    }
    
    func deleteNote(selectedRow: Int) {
        if (!notesTableView.noteList.indices.contains(selectedRow)) {
            return
        }
        
        let note = notesTableView.noteList[selectedRow]
        let alert = NSAlert.init()
        alert.messageText = "Are you sure you want to move \(note.name)\" to the trash?"
        alert.informativeText = "This action cannot be undone."
        alert.addButton(withTitle: "Remove note")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: self.view.window!) { (returnCode: NSModalResponse) -> Void in
            if returnCode == NSAlertFirstButtonReturn {
                self.editArea.clear()
                self.notesTableView.removeNote(note)
                
                if (self.notesTableView.noteList.indices.contains(selectedRow)) {
                    self.notesTableView.selectRowIndexes([selectedRow], byExtendingSelection: false)
                    self.notesTableView.scrollRowToVisible(selectedRow)
                }
            }
        }
    }
    
    func finder(selectedRow: Int) {
        if (self.notesTableView.noteList.indices.contains(selectedRow)) {
            let note = notesTableView.noteList[selectedRow]
            NSWorkspace.shared().activateFileViewerSelecting([note.url])
        }
    }
    
    func external(selectedRow: Int) {
        if (notesTableView.noteList.indices.contains(selectedRow)) {
            let note = notesTableView.noteList[selectedRow]
            
            NSWorkspace.shared().openFile(note.url.path, withApplication: UserDefaultsManagement.externalEditor)
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
    
}

