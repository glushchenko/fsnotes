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
            if (notesList.indices.contains(selectedRow)) {
                return
            }
            
            let nextRow = selectedRow
            let note = notesList[selectedRow]
            note.remove()
            
            let viewController = self.window?.contentViewController as? ViewController
            viewController?.populateTable(search: "")
            self.reloadData()
            
            //print(selectedRow)
            // select next if exist
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
        if let cell = self.makeView(withIdentifier: tableColumn!.identifier, owner: nil) as? NoteCellView
        {
            cell.preview.stringValue = notesList[row].content!
            cell.name.stringValue = notesList[row].name!
            return cell
        }
        return NoteCellView();
    }
    
    // Populate table data
    func numberOfRows(in tableView: NSTableView) -> Int {
        return notesList.count
    }
    
    // On selected row action
    func tableViewSelectionDidChange(_ notification: Notification) {
        let viewController = self.window?.contentViewController as? ViewController
        
        viewController?.textView.string = notesList[selectedRow].content!
    }
}
