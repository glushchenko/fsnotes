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
    @IBOutlet var editArea: NSTextView!
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
        
        if (notesTableView.notesList.indices.contains(0)) {
            editArea.string = notesTableView.notesList[0].content!
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
        let note = Note()
        note.content = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if note.make() {
            storage.noteList.insert(note, at: 0)
            
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
        let content = editArea.string
        var selected = notesTableView.selectedRow
        
        if (selected < 0) {
            selected = 0
        }
        
        if (notesTableView.notesList.indices.contains(selected)) {
            let note = notesTableView.notesList.remove(at: selected)
            note.content = content
            note.date = Date.init()
            
            if note.save() {
                notesTableView.notesList.insert(note, at: 0)
                notesTableView.moveRow(at: selected, to: 0)
                notesTableView.reloadData(forRowIndexes: [0], columnIndexes: [0])
                notesTableView.scrollRowToVisible(0)
            }
        }
    }
    
    // Changed search field
    override func controlTextDidChange(_ obj: Notification) {
        notesTableView.notesList.removeAll();
        self.updateTable(filter: search.stringValue)
        
        if (notesTableView.notesList.count > 0) {
            editArea.string = notesTableView.notesList[0].content!
            self.selectNullTableRow()
        }
    }
    
    func updateTable(filter: String) {
        if filter.characters.count > 0 {
            notesTableView.notesList = storage.noteList.filter() {
                if ($0.content?.localizedCaseInsensitiveContains(filter))! || ($0.name?.localizedCaseInsensitiveContains(filter))! {
                    return true
                } else {
                    return false
                }
            }
        } else {
            notesTableView.notesList = storage.noteList
        }
        
        notesTableView.reloadData()
    }
    
    override func keyUp(with event: NSEvent) {        
        // Focus search bar on ESC
        if (event.keyCode == 53) {
            search.becomeFirstResponder()
        }
    }
    
    override func controlTextDidEndEditing(_ obj: Notification) {
        search.focusRingType = .none
    }
    
    func selectNullTableRow() {
        notesTableView.selectRowIndexes([0], byExtendingSelection: false)
        notesTableView.scrollRowToVisible(0)
    }
    
    func focusEditArea() {
        DispatchQueue.main.async() {
            self.editArea.window?.makeFirstResponder(self.editArea)
        }
    }
    
    func focusTable() {
        DispatchQueue.main.async {
            self.notesTableView.window?.makeFirstResponder(self.notesTableView)
            self.selectNullTableRow()
        }
    }
}

