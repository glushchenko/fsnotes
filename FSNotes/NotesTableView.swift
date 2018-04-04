//
//  NotesTableView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/31/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Carbon
import Cocoa

class NotesTableView: NSTableView, NSTableViewDataSource,
    NSTableViewDelegate {
    
    var noteList = [Note]()
    var defaultCell = NoteCellView()
    var pinnedCell = NoteCellView()
    var storage = Storage.sharedInstance()
    
    override func draw(_ dirtyRect: NSRect) {
        self.dataSource = self
        self.delegate = self
        super.draw(dirtyRect)
    }
    
    override func keyUp(with event: NSEvent) {
        // Tab
        if (event.keyCode == 48 && !event.modifierFlags.contains(.control)) {
            let viewController = self.window?.contentViewController as? ViewController
            viewController?.focusEditArea()
        }
        
        super.keyUp(with: event)
    }
        
    // Custom note highlight style
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return NoteRowView()
    }
    
    // Populate table data
    func numberOfRows(in tableView: NSTableView) -> Int {
        return noteList.count
    }
    
    // On selected row show notes in right panel
    func tableViewSelectionDidChange(_ notification: Notification) {
        let viewController = self.window?.contentViewController as! ViewController
        
        if (noteList.indices.contains(selectedRow)) {
            viewController.editArea.fill(note: noteList[selectedRow], highlight: true)
            
            if UserDefaultsManagement.focusInEditorOnNoteSelect && !UserDataService.instance.searchTrigger {
                viewController.focusEditArea(firstResponder: nil)
            }
            
            UserDataService.instance.searchTrigger = false
        } else {
            viewController.editArea.clear()
        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if (noteList.indices.contains(row)) {
            return noteList[row]
        }
        return nil
    }
    
    func getNoteFromSelectedRow() -> Note? {
        var note: Note? = nil
        var selected = self.selectedRow
        
        if (selected < 0) {
            selected = 0
        }
        
        if (noteList.indices.contains(selected)) {
            note = noteList[selected]
        }
        
        return note
    }
    
    func getSelectedNote() -> Note? {
        var note: Note? = nil
        if (noteList.indices.contains(selectedRow)) {
            note = noteList[selectedRow]
        }
        return note
    }
    
    func getSelectedNotes() -> [Note]? {
        var notes = [Note]()
        
        for row in selectedRowIndexes {
            if (noteList.indices.contains(row)) {
                notes.append(noteList[row])
            }
        }
        
        if notes.isEmpty {
            return nil
        }
        
        return notes
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if ([kVK_ANSI_8, kVK_ANSI_J, kVK_ANSI_K].contains(Int(event.keyCode)) && event.modifierFlags.contains(.command)) {
            return true
        }
        
        if event.modifierFlags.contains(.control) {
            return true
        }
        
        if (event.keyCode == kVK_ANSI_M && event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift)) {
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard noteList.indices.contains(row) else {
            return nil
        }
        
        let note = noteList[row]
        if (note.isPinned) {
            pinnedCell = makeCell()
            pinnedCell.pin.frame.size.width = 20
            return pinnedCell
        }
        
        defaultCell = makeCell()
        defaultCell.pin.frame.size.width = 0
        return defaultCell
    }
    
    func makeCell() -> NoteCellView {
        return makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NoteCellView"), owner: self) as! NoteCellView
    }
    
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        if (clickedRow > -1 && selectedRow < 0) {
            selectRowIndexes([clickedRow], byExtendingSelection: false)
        }
    }
    
    func getIndex(_ note: Note) -> Int? {
        if let index = noteList.index(where: {$0 === note}) {
            return index
        }
        return nil
    }
    
    func selectNext() {
        selectRow(selectedRow + 1)
    }
    
    func selectPrev() {
        selectRow(selectedRow - 1)
    }
    
    func selectRow(_ i: Int) {
        if (noteList.indices.contains(i)) {
            selectRowIndexes([i], byExtendingSelection: false)
        }
    }
    
    func setSelected(note: Note) {
        if let i = getIndex(note) {
            selectRow(i)
            scrollRowToVisible(i)
        }
    }
    
    func removeByNotes(notes: [Note]) {
        for note in notes {
            if let i = noteList.index(of: note) {
                let indexSet = IndexSet(integer: i)
                noteList.remove(at: i)
                removeRows(at: indexSet, withAnimation: .effectFade)
            }
        }
    }
    
}
