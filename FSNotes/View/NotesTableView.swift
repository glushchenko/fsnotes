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
        guard let vc = self.window?.contentViewController as? ViewController else {
            super.keyUp(with: event)
            return
        }
        
        if (event.keyCode == kVK_Tab && !event.modifierFlags.contains(.control)) || event.keyCode == kVK_Return, !UserDefaultsManagement.preview {
            vc.focusEditArea()
        }
        
        if (event.keyCode == kVK_LeftArrow) {
            if let fr = self.window?.firstResponder, fr.isKind(of: NSTextView.self) {
                super.keyUp(with: event)
                return
            }
            
            vc.storageOutlineView.window?.makeFirstResponder(vc.storageOutlineView)
            vc.storageOutlineView.selectRowIndexes([1], byExtendingSelection: false)
        }
        
        super.keyUp(with: event)
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
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
            let note = noteList[selectedRow]
            
            if let items = viewController.storageOutlineView.sidebarItems {
                for item in items {
                    if item.type == .Tag {
                        if note.tagNames.contains(item.name) {
                            viewController.storageOutlineView.selectTag(item: item)
                        } else {
                            viewController.storageOutlineView.deselectTag(item: item)
                        }
                    }
                }
            }
            
            viewController.editArea.fill(note: noteList[selectedRow], highlight: true)
            
            if UserDefaultsManagement.focusInEditorOnNoteSelect && !UserDataService.instance.searchTrigger {
                viewController.focusEditArea(firstResponder: nil)
            }
        } else {
            viewController.editArea.clear()
            viewController.storageOutlineView.deselectAllTags()
        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if (noteList.indices.contains(row)) {
            return noteList[row]
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        let data = NSKeyedArchiver.archivedData(withRootObject: rowIndexes)
        let type = NSPasteboard.PasteboardType.init(rawValue: "notesTable")
        pboard.declareTypes([type], owner: self)
        pboard.setData(data, forType: type)
        return true
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
        
        if event.modifierFlags.contains(.control) && event.modifierFlags.contains(.shift) && event.keyCode == kVK_ANSI_B {
            return true
        }
        
        if event.modifierFlags.contains(.control) && event.keyCode == kVK_Tab {
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
        
        guard let vc = self.window?.contentViewController as? ViewController else { return }
        vc.loadMoveMenu()
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
            if let i = noteList.index(where: {$0 === note}) {
                let indexSet = IndexSet(integer: i)
                noteList.remove(at: i)
                removeRows(at: indexSet, withAnimation: .effectFade)
            }
        }
    }
    
    @objc public func unDelete(_ urls: [URL: URL]) {
        for (src, dst) in urls {
            do {
                try FileManager.default.moveItem(at: src, to: dst)
            } catch {
                print(error)
            }
        }
    }
    
}
