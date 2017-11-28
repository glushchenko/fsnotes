//
//  NotesTableView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/31/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa

class NotesTableView: NSTableView, NSTableViewDataSource,
    NSTableViewDelegate {
    
    var noteList = [Note]()
    var defaultCell = NoteCellView()
    var pinnedCell = NoteCellView()
    
    override func draw(_ dirtyRect: NSRect) {
        self.dataSource = self
        self.delegate = self
        super.draw(dirtyRect)
    }
    
    override func keyUp(with event: NSEvent) {
        // Tab
        if (event.keyCode == 48) {
            let viewController = self.window?.contentViewController as? ViewController
            viewController?.focusEditArea()
        }
        
        super.keyUp(with: event)
    }
    
    func removeNote(_ note: Note) {
        note.remove()
        
        let viewController = self.window?.contentViewController as! ViewController
        viewController.editArea.string = ""
        viewController.updateTable(filter: "")
        
        // select next note if exist
        let nextRow = selectedRow
        if (noteList.indices.contains(nextRow)) {
            self.selectRowIndexes([nextRow], byExtendingSelection: false)
        }
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
        } else {
            viewController.editArea.clear()
        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return noteList[row]
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
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if (
            (event.keyCode == 28 || event.keyCode == 46)
            && event.modifierFlags.contains(NSEvent.ModifierFlags.command)) {
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
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
        if (clickedRow > -1) {
            selectRowIndexes([clickedRow], byExtendingSelection: false)
        }
    }
    
    func getIndex(_ note: Note) -> Int? {
        if let index = noteList.index(where: {$0 === note}) {
            return index
        }
        return nil
    }
    
}
