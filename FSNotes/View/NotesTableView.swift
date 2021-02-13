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

    public var history = [URL]()
    public var historyPosition = 0

    public var limitedActionsList = [
        "note.print",
        "note.copyTitle",
        "note.copyURL",
        "note.rename",
        "note.saveRevision",
        "note.history"
    ]

    override func draw(_ dirtyRect: NSRect) {
        allowsTypeSelect = false
        self.gridColor = NSColor.clear
        self.dataSource = self
        self.delegate = self
        super.draw(dirtyRect)
    }

    override func keyUp(with event: NSEvent) {
        guard let vc = self.window?.contentViewController as? ViewController else {
            super.keyUp(with: event)
            return
        }
        
        if EditTextView.note != nil,
           event.keyCode == kVK_Tab && !event.modifierFlags.contains(.control)
        {
            if vc.currentPreviewState == .on {
                NSApp.mainWindow?.makeFirstResponder(vc.editArea.markdownView)
            } else {
                vc.focusEditArea()
            }

            return
        }
        
        if (event.keyCode == kVK_LeftArrow) {
            if let fr = self.window?.firstResponder, fr.isKind(of: NSTextView.self) {
                super.keyUp(with: event)
                return
            }

            vc.sidebarOutlineView.window?.makeFirstResponder(vc.sidebarOutlineView)
            if vc.sidebarOutlineView.selectedRowIndexes.count == 0 {
                vc.sidebarOutlineView.selectRowIndexes([0], byExtendingSelection: false)
            }

            return
        }

        super.keyUp(with: event)
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        UserDataService.instance.searchTrigger = false

        ViewController.shared()?.restoreCurrentPreviewState()

        super.mouseDown(with: event)
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if (noteList.indices.contains(row)) {
            saveNavigationHistory(note: noteList[row])
        }
        return true
    }

    override func rightMouseDown(with event: NSEvent) {
        UserDataService.instance.searchTrigger = false

        let point = self.convert(event.locationInWindow, from: nil)
        let i = row(at: point)
        
        if noteList.indices.contains(i) {
            saveNavigationHistory(note: noteList[i])

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
            if row < noteList.count {
                let note = noteList[row]
                note.loadPreviewInfo()

                if let urls = note.imageUrl, urls.count > 0 {
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
            if vc.sidebarOutlineView.selectedRow == -1 {
                UserDataService.instance.isNotesTableEscape = false
            }
            
            vc.sidebarOutlineView.deselectAll(nil)
            vc.sidebarOutlineView.reloadTags()
            vc.editArea.clear()
            return
        }
        
        if (noteList.indices.contains(selectedRow)) {
            let note = noteList[selectedRow]

            if !UserDefaultsManagement.inlineTags, let items = vc.sidebarOutlineView.sidebarItems {
                for item in items {
                    if let tag = item as? Tag {
                        if note.tagNames.contains(tag.getName()) {
                            vc.sidebarOutlineView.selectTag(item: tag)
                        } else {
                            vc.sidebarOutlineView.deselectTag(item: tag)
                        }
                    }
                }
            }

            self.loadingQueue.cancelAllOperations()
            let operation = BlockOperation()
            operation.addExecutionBlock { [weak self] in        
                DispatchQueue.main.async {
                    guard self?.selectedRowIndexes.count == 0x01 else {
                        vc.editArea.clear()
                        return
                    }

                    guard !operation.isCancelled,
                          self?.fillTimestamp == timestamp else { return }

                    vc.editArea.fill(note: note, highlight: true)

                    if UserDefaultsManagement.focusInEditorOnNoteSelect && !UserDataService.instance.searchTrigger {
                        vc.focusEditArea()
                    }
                }
            }
            self.loadingQueue.addOperation(operation)

        } else {
            vc.editArea.clear()

            if !UserDefaultsManagement.inlineTags {
                vc.sidebarOutlineView.deselectAllTags()
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if (noteList.indices.contains(row)) {
            return noteList[row]
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        var title = String()
        var urls = [URL]()
        for row in rowIndexes {
            let note = noteList[row]
            urls.append(note.url)

            title = note.title
        }

        pboard.setString(title, forType: NSPasteboard.PasteboardType.string)

        let data = NSKeyedArchiver.archivedData(withRootObject: urls)
        pboard.setData(data, forType: NSPasteboard.noteType)

        return true
    }

    @IBAction func copy(_ sender: Any) {
        guard let vc = ViewController.shared() else { return }

        vc.saveTextAtClipboard()
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
        if let char = event.characters?.unicodeScalars.first,
           ["j", "k"].contains(char) && event.modifierFlags.contains(.command)
        {
            return true
        }

        if self.window?.firstResponder == self,
           !event.modifierFlags.contains(.shift),
           event.keyCode == kVK_DownArrow || event.keyCode == kVK_UpArrow {
            ViewController.shared()?.restoreCurrentPreviewState()
        }

        if event.keyCode == kVK_LeftArrow, let fr = self.window?.firstResponder, fr.isKind(of: NotesTableView.self) {
            return true
        }

        if event.modifierFlags.contains(.control) && event.keyCode == kVK_Tab {
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

        menu.autoenablesItems = false

        for menuItem in menu.items {
            if let identifier = menuItem.identifier?.rawValue,
                limitedActionsList.contains(identifier)
            {
                menuItem.isEnabled = (vc.notesTableView.selectedRowIndexes.count == 1)
            }

            if menuItem.identifier?.rawValue == "fileMenu.removeEncryption" {
                if let note = EditTextView.note {
                    menuItem.isEnabled = note.isEncrypted()
                }
            }
        }

        vc.loadMoveMenu()
    }
    
    func getIndex(_ note: Note) -> Int? {
        if let index = noteList.firstIndex(where: {$0 === note}) {
            return index
        }
        return nil
    }
    
    public func selectNext() {
        guard let vc = ViewController.shared() else { return }
        vc.restoreCurrentPreviewState()

        UserDataService.instance.searchTrigger = false

        let i = selectedRow + 1
        if (noteList.indices.contains(i)) {
            saveNavigationHistory(note: noteList[i])
        }

        selectRow(selectedRow + 1)
    }
    
    public func selectPrev() {
        guard let vc = ViewController.shared() else { return }
        vc.restoreCurrentPreviewState()

        UserDataService.instance.searchTrigger = false

        let i = selectedRow - 1
        if (noteList.indices.contains(i)) {
            saveNavigationHistory(note: noteList[i])
        }

        selectRow(selectedRow - 1)
    }
    
    public func selectRow(_ i: Int) {
        if (noteList.indices.contains(i)) {
            DispatchQueue.main.async {
                self.selectRowIndexes([i], byExtendingSelection: false)
                self.scrollRowToVisible(i)
            }
        }
    }

    public func selectRowAndSidebarItem(note: Note) {
        guard let vc = ViewController.shared() else { return }

        if let index = getIndex(note) {
            selectRow(index)
        } else {
            vc.sidebarOutlineView.select(note: note)
        }
    }

    func setSelected(note: Note) {
        if let i = getIndex(note) {
            selectRow(i)
            scrollRowToVisible(i)
        }
    }
    
    func removeByNotes(notes: [Note]) {
        guard let vc = ViewController.shared() else { return }

        beginUpdates()
        for note in notes {
            if let i = noteList.firstIndex(where: {$0 === note}) {
                let indexSet = IndexSet(integer: i)
                noteList.remove(at: i)
                removeRows(at: indexSet, withAnimation: .slideDown)
            }
        }
        endUpdates()

        if UserDefaultsManagement.inlineTags {
            vc.sidebarOutlineView.removeTags(notes: notes)
        }
    }
    
    @objc public func unDelete(_ urls: [URL: URL]) {
        for (src, dst) in urls {
            do {
                if let note = storage.getBy(url: src) {
                    storage.removeBy(note: note)

                    if let destination = Storage.sharedInstance().getProjectByNote(url: dst) {
                        note.moveImages(to: destination)
                    }
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

        guard noteList.first(where: { $0.isEqualURL(url: note.url) }) == nil else { return }

        let type = vc.getSidebarType() ?? .Inbox
        guard vc.isFit(note: note, shouldLoadMain: true, type: type) else { return }

        let at = self.countVisiblePinned()
        self.noteList.insert(note, at: at)
        
        self.beginUpdates()
        self.insertRows(at: IndexSet(integer: at), withAnimation: .effectFade)
        self.reloadData(forRowIndexes: IndexSet(integer: at), columnIndexes: [0])
        self.endUpdates()

        vc.sidebarOutlineView.insertTags(note: note)
    }

    public func reloadRow(note: Note) {
        note.invalidateCache()
        note.loadPreviewInfo()
        let urls = note.imageUrl

        DispatchQueue.main.async {
            if let i = self.noteList.firstIndex(of: note) {
                if let row = self.rowView(atRow: i, makeIfNecessary: false) as? NoteRowView, let cell = row.subviews.first as? NoteCellView {

                    cell.date.stringValue = note.getDateForLabel()
                    cell.loadImagesPreview(position: i, urls: urls)
                    cell.attachHeaders(note: note)
                    cell.renderPin()

                    self.noteHeightOfRows(withIndexesChanged: [i])
                }
            }
        }
    }

    public func saveNavigationHistory(note: Note) {
        guard history.last != note.url else {
            historyPosition = history.count - 1
            return
        }

        history.append(note.url)
        historyPosition = history.count - 1
    }
}
