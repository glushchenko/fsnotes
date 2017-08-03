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
            
            viewController?.editArea.string = ""
            viewController?.populateTable(search: "")
            self.reloadData()
            
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
    
    // Custom cell style
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = self.make(withIdentifier: tableColumn!.identifier, owner: nil) as? NoteCellView
        {
            let text = notesList[row].content!
            cell.preview.sizeToFit()
            cell.preview.maximumNumberOfLines = 3
            cell.preview.stringValue = text
            cell.name.stringValue = notesList[row].name!
            return cell
        }
        return NoteCellView();
    }
    
    // Populate table data
    func numberOfRows(in tableView: NSTableView) -> Int {
        return notesList.count
    }
    
    // On selected row show notes in right panel
    func tableViewSelectionDidChange(_ notification: Notification) {
        let viewController = self.window?.contentViewController as? ViewController
        viewController?.lastSelectedNote = notesList[selectedRow]
        viewController?.editArea.string = notesList[selectedRow].content!
    }
}
