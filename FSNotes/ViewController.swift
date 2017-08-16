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
            if (!notesTableView.noteList.indices.contains(notesTableView.selectedRow)) {
                return
            }
            
            let note = notesTableView.noteList[notesTableView.selectedRow]
            let alert = NSAlert.init()
            alert.messageText = "Are you sure you want to move \(note.name)\" to the trash?"
            alert.informativeText = "This action cannot be undone."
            alert.addButton(withTitle: "Remove note")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: self.view.window!) { (returnCode: NSModalResponse) -> Void in
                if returnCode == NSAlertFirstButtonReturn {
                    self.notesTableView.removeNote(note)
                }
            }
        }
        
        // Note edit mode and select file name (cmd-r)
        if (event.keyCode == 15 && event.modifierFlags.contains(.command)) {
            if (!notesTableView.noteList.indices.contains(notesTableView.selectedRow)) {
                return
            }
            
            let row = notesTableView.rowView(atRow: notesTableView.selectedRow, makeIfNecessary: false) as! NoteRowView
            let cell = row.view(atColumn: 0) as! NoteCellView
            
            cell.name.isEditable = true
            cell.name.becomeFirstResponder()
            
            let fileName = cell.name.currentEditor()!.string! as NSString
            let fileNameLength = fileName.length - fileName.pathExtension.characters.count - 1
            
            cell.name.currentEditor()?.selectedRange = NSMakeRange(0, fileNameLength)
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
            self.selectNullTableRow()
            
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
            
            notesTableView.noteList.remove(at: selected)
            notesTableView.noteList.insert(note, at: 0)
            
            if editArea.save(note: note) {
                notesTableView.moveRow(at: selected, to: 0)
                notesTableView.reloadData(forRowIndexes: [0, selected], columnIndexes: [0])
                notesTableView.scrollRowToVisible(0)
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
                .sorted(by: { $0.date! > $1.date! })
        
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
        
        cleanSearchAndEditArea()
    }
}

