//
//  NotesTableView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 7/31/17.
//  Copyright © 2017 Oleksandr Glushchenko. All rights reserved.
//

import Carbon
import Cocoa
import FSNotesCore_macOS

class NotesTableView: NSTableView, NSTableViewDataSource,
    NSTableViewDelegate {
    
    var noteList = [Note]()
    var defaultCell = NoteCellView()
    var pinnedCell = NoteCellView()
    var storage = Storage.sharedInstance()

    public var loadingQueue = OperationQueue.init()
    public var fillTimestamp: Int64?
    
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
        
        if (event.keyCode == kVK_Tab && !event.modifierFlags.contains(.control)), !UserDefaultsManagement.preview {
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
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        UserDataService.instance.searchTrigger = false

        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        UserDataService.instance.searchTrigger = false

        let point = self.convert(event.locationInWindow, from: nil)
        let i = row(at: point)
        
        if self.noteList.indices.contains(i) {
            DispatchQueue.main.async {
                let selectedRows = self.selectedRowIndexes
                if !selectedRows.contains(i) {
                    self.selectRowIndexes(IndexSet(integer: i), byExtendingSelection: false)
                    self.scrollRowToVisible(i)
                    return
                }
            }

            super.rightMouseDown(with: event)
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

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let height = CGFloat(21 + UserDefaultsManagement.cellSpacing)

        if !UserDefaultsManagement.horizontalOrientation && !UserDefaultsManagement.hidePreviewImages {
            if noteList.indices.contains(row) {
                let note = noteList[row]

                if let urls = note.getImagePreviewUrl(), urls.count > 0 {
                    let previewCharsQty = note.preview.count

                    if (previewCharsQty == 0) {
                        if note.getTitle() != nil {
                            // Title + image
                            return 79 + 17
                        }

                        // Images only
                        return 79
                    }

                    // Title + Prevew + Images
                    return (height + 58)
                }
            }
        }

        // Title + preview
        return height
    }
    
    // On selected row show notes in right panel
    func tableViewSelectionDidChange(_ notification: Notification) {
        let timestamp = Date().toMillis()
        self.fillTimestamp = timestamp

        let vc = self.window?.contentViewController as! ViewController

        if vc.editAreaScroll.isFindBarVisible {
            let menu = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            menu.tag = NSTextFinder.Action.hideFindInterface.rawValue
            vc.editArea.performTextFinderAction(menu)
        }

        if UserDataService.instance.isNotesTableEscape {
            if vc.storageOutlineView.selectedRow == -1 {
                UserDataService.instance.isNotesTableEscape = false
            }
            
            vc.storageOutlineView.deselectAll(nil)
            vc.editArea.clear()
            return
        }
        
        if (noteList.indices.contains(selectedRow)) {
            let note = noteList[selectedRow]
            
            if let items = vc.storageOutlineView.sidebarItems {
                for item in items {
                    if item.type == .Tag {
                        if note.tagNames.contains(item.name) {
                            vc.storageOutlineView.selectTag(item: item)
                        } else {
                            vc.storageOutlineView.deselectTag(item: item)
                        }
                    }
                }
            }

            self.loadingQueue.cancelAllOperations()
            let operation = BlockOperation()
            operation.addExecutionBlock { [weak self] in        
                DispatchQueue.main.async {
                    guard !operation.isCancelled, self?.fillTimestamp == timestamp else { return }

                    vc.editArea.fill(note: note, highlight: true)
                    if UserDefaultsManagement.focusInEditorOnNoteSelect && !UserDataService.instance.searchTrigger {
                        vc.focusEditArea(firstResponder: nil)
                    }
                }
            }
            self.loadingQueue.addOperation(operation)

        } else {
            vc.editArea.clear()
            vc.storageOutlineView.deselectAllTags()
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
        let selected = self.selectedRow

        if (selected < 0) {
            return nil
        }
        
        if (noteList.indices.contains(selected)) {
            note = noteList[selected]
        }
        
        return note
    }
    
    func getSelectedNote() -> Note? {
        var note: Note? = nil
        let row = selectedRow
        if (noteList.indices.contains(row)) {
            note = noteList[row]
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
    
    public func deselectNotes() {
        self.deselectAll(nil)
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
            pinnedCell = makeCell(note: note)
            pinnedCell.pin.frame.size.width = 23
            return pinnedCell
        }
        
        defaultCell = makeCell(note: note)
        defaultCell.pin.frame.size.width = 0
        return defaultCell
    }
    
    func makeCell(note: Note) -> NoteCellView {
        let cell = makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NoteCellView"), owner: self) as! NoteCellView

        cell.configure(note: note)
        cell.loadImagesPreview()
        cell.attachHeaders(note: note)

        return cell
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        if (clickedRow > -1 && selectedRow < 0) {
            selectRowIndexes([clickedRow], byExtendingSelection: false)
        }

        if selectedRow < 0 {
            return
        }

        guard let vc = self.window?.contentViewController as? ViewController else { return }
        vc.loadMoveMenu()
    }
    
    func getIndex(_ note: Note) -> Int? {
        if let index = noteList.firstIndex(where: {$0 === note}) {
            return index
        }
        return nil
    }
    
    func selectNext() {
        UserDataService.instance.searchTrigger = false

        selectRow(selectedRow + 1)
    }
    
    func selectPrev() {
        UserDataService.instance.searchTrigger = false
        
        selectRow(selectedRow - 1)
    }
    
    func selectRow(_ i: Int) {
        if (noteList.indices.contains(i)) {
            DispatchQueue.main.async {
                self.selectRowIndexes([i], byExtendingSelection: false)
                self.scrollRowToVisible(i)
            }
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
            if let i = noteList.firstIndex(where: {$0 === note}) {
                let indexSet = IndexSet(integer: i)
                noteList.remove(at: i)
                removeRows(at: indexSet, withAnimation: .slideDown)
            }
        }
    }
    
    @objc public func unDelete(_ urls: [URL: URL]) {
        for (src, dst) in urls {
            do {
                if let note = storage.getBy(url: src) {
                    storage.removeBy(note: note)
                }

                try FileManager.default.moveItem(at: src, to: dst)
            } catch {
                print(error)
            }
        }
    }
    
    public func countVisiblePinned() -> Int {
        var i = 0
        for note in noteList {
            if (note.isPinned) {
                i += 1
            }
        }
        return i
    }
    
    public func insertNew(note: Note) {
        guard let vc = self.window?.contentViewController as? ViewController else { return }

        guard vc.isFit(note: note, shouldLoadMain: true) else { return }

        let at = self.countVisiblePinned()
        self.noteList.insert(note, at: at)
        vc.filteredNoteList?.insert(note, at: at)
        
        self.beginUpdates()
        self.insertRows(at: IndexSet(integer: at), withAnimation: .effectFade)
        self.reloadData(forRowIndexes: IndexSet(integer: at), columnIndexes: [0])
        self.endUpdates()
    }

    public func reloadRow(note: Note) {
        DispatchQueue.main.async {
            if let i = self.noteList.firstIndex(of: note) {
                note.invalidateCache()
                if let row = self.rowView(atRow: i, makeIfNecessary: false) as? NoteRowView, let cell = row.subviews.first as? NoteCellView {

                    cell.date.stringValue = note.getDateForLabel()
                    cell.loadImagesPreview(position: i)
                    cell.attachHeaders(note: note)
                    cell.renderPin()

                    self.noteHeightOfRows(withIndexesChanged: [i])
                }
            }
        }
    }
    
}
