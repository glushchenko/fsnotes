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
    
    var notesList = [Note]()
    
    override func draw(_ dirtyRect: NSRect) {
        self.dataSource = self
        self.delegate = self
        super.draw(dirtyRect)
    }
    
    // Remove note
    override func keyDown(with event: NSEvent) {
        if (event.keyCode == 51) {
            if (!notesList.indices.contains(selectedRow)) {
                return
            }
            
            let nextRow = selectedRow
            let note = notesList[selectedRow]
            note.remove()
            
            let viewController = self.window?.contentViewController as? ViewController
            viewController?.storage.noteList.remove(at: selectedRow)
            viewController?.editArea.string = ""
            viewController?.updateTable(filter: "")
            
            // select next note if exist
            if (notesList.indices.contains(nextRow)) {
                self.selectRowIndexes([nextRow], byExtendingSelection: false)
            }
        }
        
        super.keyDown(with: event)
    }
    
    // Custom note highlight style
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return NoteRowView()
    }
    
    // Populate table data
    func numberOfRows(in tableView: NSTableView) -> Int {
        return notesList.count
    }
    
    // On selected row show notes in right panel
    func tableViewSelectionDidChange(_ notification: Notification) {
        let viewController = self.window?.contentViewController as? ViewController
        
        if (notesList.indices.contains(selectedRow)) {
            viewController?.editArea.string = notesList[selectedRow].content!
        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return notesList[row]
    }
    
    func getNoteFromSelectedRow() -> Note {
        var note = Note()
        var selected = self.selectedRow
        
        if (selected < 0) {
            selected = 0
        }
        
        if (notesList.indices.contains(selected)) {
            note = notesList[selected]
        }
        
        return note
    }
}
