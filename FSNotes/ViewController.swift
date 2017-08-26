//
//  ViewController.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/20/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class ViewController: NSViewController,
    NSTextViewDelegate,
    NSTextFieldDelegate {
    
    var lastSelectedNote: Note?
    let storage = Storage()
    
    @IBOutlet var emptyEditAreaImage: NSImageView!
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var searchWrapper: NSTextField!
    @IBOutlet var editArea: EditTextView!
    @IBOutlet weak var editAreaScroll: NSScrollView!
    @IBOutlet weak var search: SearchTextField!
    @IBOutlet weak var notesTableView: NotesTableView!
    
    override func viewDidAppear() {
        self.view.window!.title = "FSNotes"
                
        // autosave size and position
        self.view.window?.setFrameAutosaveName("MainWindow")
        splitView.autosaveName = "SplitView"
        
        // editarea paddings
        editArea.textContainerInset.height = 10
        editArea.textContainerInset.width = 5
        editArea.isEditable = false
        
        if (UserDefaultsManagement.horizontalOrientation) {
            self.splitView.isVertical = false
            notesTableView.rowHeight = 25
        }
        
        if (UserDefaultsManagement.hidePreview && !UserDefaultsManagement.horizontalOrientation) {
            notesTableView.rowHeight = 28
        }
        
        super.viewDidAppear()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let bookmark = SandboxBookmark()
        bookmark.load()
        
        editArea.delegate = self
        search.delegate = self
        
        if storage.noteList.count == 0 {
            storage.loadFiles()
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
            deleteNote(selectedRow: notesTableView.selectedRow)
        }
        
        // Note edit mode and select file name (cmd-r)
        if (event.keyCode == 15 && event.modifierFlags.contains(.command)) {
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
    }
        
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func makeNote(_ sender: NSTextField) {
        editArea.string = ""
        
        let note = Note()
        let nextId = storage.getNextId()
        note.make(id: nextId, newName: sender.stringValue)
        
        if editArea.save(note: note) {
            storage.add(note: note)
            
            self.updateTable(filter: "")
            
            let index = Storage.pinned
            notesTableView.selectRowIndexes([index], byExtendingSelection: false)
            notesTableView.scrollRowToVisible(index)
            
            focusEditArea()
            search.stringValue.removeAll()
        }
    }
    
    @IBAction func fileName(_ sender: NSTextField) {
        let note = notesTableView.getNoteFromSelectedRow()
        sender.isEditable = false
        if (!note.rename(newName: sender.stringValue)) {
            sender.stringValue = note.name
        }
    }
    
    @IBAction func makeMenu(_ sender: Any) {
        makeNote(NSTextField())
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
    
    @IBAction func openInFinder(_ sender: Any) {
        let note = notesTableView.noteList[notesTableView.clickedRow]
        NSWorkspace.shared().activateFileViewerSelecting([note.url])
    }
    
    // Changed main edit view
    func textDidChange(_ notification: Notification) {
        let selected = notesTableView.selectedRow
        
        if (
            notesTableView.noteList.indices.contains(selected)
            && selected > -1
        ) {
            let content = editArea.string!
            let note = notesTableView.noteList[selected]
            let storageId = note.id
            note.content = content
            
            storage.noteList[storageId].date = Date()
            storage.noteList[storageId].content = content
            
            if editArea.save(note: note) {
                moveAtTop(id: selected)
            }
        }
    }
    
    // Changed search field
    override func controlTextDidChange(_ obj: Notification) {
        notesTableView.noteList.removeAll();
        self.updateTable(filter: search.stringValue)
        
        if (notesTableView.noteList.count > 0) {
            editArea.fill(note: notesTableView.noteList[0])
            self.selectNullTableRow()
        } else {
            editArea.clear()
        }
    }
    
    func updateTable(filter: String) {
        notesTableView.noteList =
            storage.noteList
                .filter() {
                    return (
                        $0.isRemoved == false
                        && (
                            filter.isEmpty
                            || (
                                !filter.isEmpty
                                && (
                                    $0.content.localizedCaseInsensitiveContains(filter)
                                    || $0.name.localizedCaseInsensitiveContains(filter)
                                )
                            )
                        )
                    )
                }
                .sorted(by: {
                    $0.date! > $1.date!
                })
                .sorted(by: {
                    $0.isPinned && !$1.isPinned
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
        NSApp.activate(ignoringOtherApps: true)
        self.view.window?.makeKeyAndOrderFront(self)
        
        if (notesTableView.noteList[0].content.characters.count == 0) {
            selectNullTableRow()
            focusEditArea()
        } else {
            makeNote(NSTextField())
        }
    }
    
    func searchShortcut() {
        NSApp.activate(ignoringOtherApps: true)
        self.view.window?.makeKeyAndOrderFront(self)
        
        search.becomeFirstResponder()
    }
    
    func moveAtTop(id: Int) {
        let isPinned = notesTableView.noteList[id].isPinned
        let position = isPinned ? 0 : Storage.pinned
        let note = notesTableView.noteList.remove(at: id)
        
        notesTableView.noteList.insert(note, at: position)
        notesTableView.moveRow(at: id, to: position)
        notesTableView.reloadData(forRowIndexes: [id, position], columnIndexes: [0])
        notesTableView.scrollRowToVisible(0)
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
    
}

