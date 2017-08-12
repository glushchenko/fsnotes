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
        editArea.textContainerInset.height = 5
        editArea.textContainerInset.width = 5
        editArea.isEditable = false
        
        if (UserDefaultsManagement.horizontalOrientation) {
            self.splitView.isVertical = false
            notesTableView.rowHeight = 25
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
        
        let fontName = UserDefaultsManagement.fontName
        let font = NSFont(name: fontName, size: 13)
        editArea.font = font
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func makeNote(_ sender: NSTextField) {
        editArea.string = ""
        
        let nextId: Int = storage.noteList.count
        let note = Note()
        note.make(id: nextId)
        
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
        note.rename(newName: sender.stringValue)
    }
    
    // Changed main edit view
    func textDidChange(_ notification: Notification) {
        let selected = notesTableView.selectedRow
        
        if (
            notesTableView.notesList.indices.contains(selected)
            && selected > -1
        ) {
            let content = editArea.string!
            
            let note = storage.filterList[selected]
            note.content = content
            
            let storageKey = note.id
            
            storage.noteList[storageKey].date = Date()
            storage.noteList[storageKey].content = content
            
            storage.filterList.remove(at: selected)
            storage.filterList.insert(note, at: 0)
            
            notesTableView.notesList.remove(at: selected)
            notesTableView.notesList.insert(note, at: 0)
            
            if editArea.save(note: note) {
                notesTableView.moveRow(at: selected, to: 0)
                notesTableView.reloadData(forRowIndexes: [0, selected], columnIndexes: [0])
                notesTableView.scrollRowToVisible(0)
            }
        }
    }
    
    // Changed search field
    override func controlTextDidChange(_ obj: Notification) {
        notesTableView.notesList.removeAll();
        self.updateTable(filter: search.stringValue)
        
        if (notesTableView.notesList.count > 0) {
            editArea.fill(note: notesTableView.notesList[0])
            self.selectNullTableRow()
        } else {
            editArea.clear()
        }
    }
    
    func updateTable(filter: String) {
        if filter.characters.count > 0 {
            storage.filterList = storage.noteList.filter() {
                if ($0.content.localizedCaseInsensitiveContains(filter)) || ($0.name?.localizedCaseInsensitiveContains(filter))!
                {
                    return true
                } else {
                    return false
                }
            }
            .sorted(by: { $0.date! > $1.date! })
            .filter() {
                return ($0.isRemoved == false)
            }
        } else {
            storage.filterList =
                storage.noteList
                    .sorted(by: { $0.date! > $1.date! })
                    .filter() {
                        return ($0.isRemoved == false)
                    }
        }
        
        notesTableView.notesList = storage.filterList
        notesTableView.reloadData()
    }
    
    override func keyUp(with event: NSEvent) {
        // Focus search bar on ESC
        if (event.keyCode == 53) {
            search.becomeFirstResponder()
            notesTableView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
            search.stringValue = ""
            editArea.clear()
            updateTable(filter: "")
        }
        
        super.keyUp(with: event)
    }
    
    // Focus search field shortcut (cmd-L)
    override func keyDown(with event: NSEvent) {
        if (event.keyCode == 37 && event.modifierFlags.contains(.command)) {
            search.becomeFirstResponder()
        }
        
        super.keyDown(with: event)
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
}

