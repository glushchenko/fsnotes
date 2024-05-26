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
    var storage = Storage.shared()

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

    private var selectedHistory: IndexSet?

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
        
        if event.keyCode == kVK_Tab && !event.modifierFlags.contains(.control) {
            if vc.editor?.isPreviewEnabled() == true {
                NSApp.mainWindow?.makeFirstResponder(vc.editor.markdownView)
            } else {
                vc.focusEditArea()
            }

            return
        }
        
        super.keyUp(with: event)
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        guard let vc = self.window?.contentViewController as? ViewController else { return }
        
        if let selectedProject = vc.sidebarOutlineView.getSelectedProject(),
            selectedProject.isLocked()
        {
            vc.toggleFolderLock(NSMenuItem())
            return
        }
        
        UserDataService.instance.searchTrigger = false

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

        let point = convert(event.locationInWindow, from: nil)
        let rowIndex = row(at: point)
        if (rowIndex < 0 || self.numberOfRows < rowIndex) {
            return
        }

        saveNavigationHistory(note: noteList[rowIndex])

        if !selectedRowIndexes.contains(rowIndex) {
            selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
            scrollRowToVisible(rowIndex)
        }

        if rowView(atRow: rowIndex, makeIfNecessary: false) as? NoteRowView != nil {
            if let menu = menu {
                NSMenu.popUpContextMenu(menu, with: event, for: self)
            }
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

        guard row < noteList.count else { return height }

        let note = noteList[row]
        if !note.isLoaded && !note.isLoadedFromCache {
            note.load()
        }

        if !UserDefaultsManagement.horizontalOrientation
            && !UserDefaultsManagement.hidePreviewImages,
            let urls = note.imageUrl,
            urls.count > 0{

            if note.preview.count == 0 {
                if note.getTitle() != nil {
                    // Title + image
                    return 79 + 17
                }

                // Images only
                return 79
            }

            // Title + Prevew + Images
            return height + 58
        }

        // Title + preview
        return height
    }

    // On selected row show notes in right panel
    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedHistory = selectedRowIndexes

        let vc = self.window?.contentViewController as! ViewController
        if vc.editAreaScroll.isFindBarVisible {
            let menu = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            menu.tag = NSTextFinder.Action.hideFindInterface.rawValue
            vc.editor.performTextFinderAction(menu)
        }

        if UserDataService.instance.isNotesTableEscape {
            if vc.sidebarOutlineView.selectedRow == -1 {
                UserDataService.instance.isNotesTableEscape = false
            }
            
            vc.sidebarOutlineView.deselectAll(nil)
            vc.sidebarOutlineView.reloadTags()
            vc.editor.clear()
            return
        }

        // Select row
        if (noteList.indices.contains(selectedRow)) {
            let note = noteList[selectedRow]

            guard selectedRowIndexes.count == 0x01 else {
                vc.editor.clear()
                return
            }
            
            vc.editor.changePreviewState(note.previewState)
            vc.editor.fill(note: note, highlight: true)

            if UserDefaultsManagement.focusInEditorOnNoteSelect && !UserDataService.instance.searchTrigger {
                vc.focusEditArea()
            }

            return
        }

        // Clean
        vc.editor.clear()

        if !UserDefaultsManagement.inlineTags {
            vc.sidebarOutlineView.deselectAllTags()
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

            if let unwarpped = note.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                title = "fsnotes://find/" +  unwarpped
            }
        }

        pboard.setString(title, forType: NSPasteboard.PasteboardType.string)

        if let data = try? NSKeyedArchiver.archivedData(withRootObject: urls, requiringSecureCoding: false) {
            pboard.setData(data, forType: NSPasteboard.noteType)
        }

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
        if clickedRow > -1 {
            selectRowIndexes([clickedRow], byExtendingSelection: false)
        }

        if selectedRow < 0 {
            return
        }

        guard let vc = self.window?.contentViewController as? ViewController else { return }

        menu.autoenablesItems = false

        var note = vc.editor.note
        
        if note == nil {
            note = vc.getSelectedNotes()?.first
        }
        
        for menuItem in menu.items {
            if let identifier = menuItem.identifier?.rawValue,
                limitedActionsList.contains(identifier)
            {
                menuItem.isEnabled = (vc.notesTableView.selectedRowIndexes.count == 1)
            }

            if menuItem.identifier?.rawValue == "note.saveRevision" {
                if let note = note {
                    let hasCommits = note.project.hasCommitsDiffsCache()
                    menuItem.isHidden = !hasCommits
                }
            }
            
            if menuItem.identifier?.rawValue == "fileMenu.pinUnpin" {
                if let note = note {
                    menuItem.title = note.isPinned
                        ? NSLocalizedString("Unpin", comment: "")
                        : NSLocalizedString("Pin", comment: "")
                }
            }
            
            if menuItem.identifier?.rawValue == "note.toggleContainer" {
                if let note = note, note.container != .encryptedTextPack {
                    menuItem.title = note.container == .none
                        ? NSLocalizedString("Convert to TextBundle", comment: "")
                        : NSLocalizedString("Convert to Plain", comment: "")
                    
                    menuItem.isEnabled = true
                } else {
                    menuItem.isEnabled = false
                }
            }
            
            if menuItem.identifier?.rawValue == "fileMenu.lockUnlock" {
                if let note = note {
                    menuItem.title = note.isEncryptedAndLocked()
                        ? NSLocalizedString("Unlock", comment: "")
                        : NSLocalizedString("Lock", comment: "")
                }
            }

            if menuItem.identifier?.rawValue == "fileMenu.removeEncryption" {
                if let note = note, note.isEncrypted() {
                    menuItem.isEnabled = true
                    menuItem.isHidden = false
                } else {
                    menuItem.isEnabled = false
                    menuItem.isHidden = true
                }
            }
            
            if menuItem.identifier?.rawValue == "noteMenu.removeOverSSH" {
                if let note = vc.editor.note, !note.isEncrypted(), note.uploadPath != nil || note.apiId != nil {
                    menuItem.isHidden = false
                } else {
                    menuItem.isHidden = true
                }
            }
            
            if menuItem.identifier?.rawValue == "noteMenu.uploadOverSSH" {
                if let note = vc.editor.note, !note.isEncrypted() {
                    if note.uploadPath != nil || note.apiId != nil {
                        menuItem.title = NSLocalizedString("Update Web Page", comment: "")
                    } else {
                        menuItem.title = NSLocalizedString("Create Web Page", comment: "")
                    }
                    
                    menuItem.isHidden = false
                } else {
                    menuItem.isHidden = true
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

    public func selectCurrent() {
        guard noteList.count > 0 else { return }

        UserDataService.instance.searchTrigger = false

        let i = selectedRowIndexes.count > 0 ? selectedRowIndexes : [0]

        if let first = i.first {
            saveNavigationHistory(note: noteList[first])
            selectRowIndexes(i, byExtendingSelection: false)
            scrollRowToVisible(first)
        }
    }

    public func selectNext() {
        UserDataService.instance.searchTrigger = false

        let i = selectedRow + 1
        if (noteList.indices.contains(i)) {
            saveNavigationHistory(note: noteList[i])
        }

        if (noteList.indices.contains(i)) {
            self.selectRowIndexes([i], byExtendingSelection: false)
            self.scrollRowToVisible(i)
        }
    }
    
    public func selectPrev() {
        UserDataService.instance.searchTrigger = false

        let i = selectedRow - 1
        if (noteList.indices.contains(i)) {
            saveNavigationHistory(note: noteList[i])
        }

        if (noteList.indices.contains(i)) {
            self.selectRowIndexes([i], byExtendingSelection: false)
            self.scrollRowToVisible(i)
        }
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
    
    public func removeRows(notes: [Note]) {
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
    
    public func insertRows(notes: [Note]) {
        guard let vc = self.window?.contentViewController as? ViewController else { return }
        var insert = [Note]()
        
        for note in notes {
            if noteList.first(where: { $0.isEqualURL(url: note.url) }) == nil,
               vc.isFit(note: note, shouldLoadMain: true) {
                insert.append(note)
                noteList.append(contentsOf: insert)
            }
        }
        
        let projects = vc.sidebarOutlineView.getSidebarProjects()
        self.noteList = vc.storage.sortNotes(noteList: self.noteList, filter: vc.search.stringValue, project: projects?.first)
        
        var indexSet = IndexSet()
        for note in insert {
            if let noteIndex = self.noteList.firstIndex(of: note) {
                indexSet.insert(noteIndex)
            }
        }
        
        self.insertRows(at: indexSet, withAnimation: .effectFade)
        
        for note in insert {
            vc.sidebarOutlineView.insertTags(note: note)
        }
    }
    
    private func reloadRows(notes: [Note]) {
        for note in notes {
            reloadRow(note: note)
        }
    }
    
    @objc public func unDelete(_ urls: [URL: URL]) {
        for (src, dst) in urls {
            do {
                if let note = storage.getBy(url: src) {
                    storage.removeBy(note: note)

                    if let destination = Storage.shared().getProjectByNote(url: dst) {
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

    public func reloadRow(note: Note) {
        note.invalidateCache()
        note.loadPreviewInfo()
        let urls = note.imageUrl

        DispatchQueue.main.async {
            if let i = self.noteList.firstIndex(of: note) {
                if let row = self.rowView(atRow: i, makeIfNecessary: false) as? NoteRowView {

                    if let cell = row.subviews.first as? NoteCellView {

                        cell.date.stringValue = note.getDateForLabel()
                        cell.loadImagesPreview(position: i, urls: urls)
                        cell.attachHeaders(note: note)
                        cell.renderPin()
                        cell.applyPreviewStyle()

                        self.noteHeightOfRows(withIndexesChanged: [i])
                    }
                }
            }
        }
    }
    
    public func reloadDate(note: Note) {
        DispatchQueue.main.async {
            if self.numberOfRows > 0, let i = self.noteList.firstIndex(of: note) {
                if let row = self.rowView(atRow: i, makeIfNecessary: false) as? NoteRowView {
                    if let cell = row.subviews.first as? NoteCellView {
                        cell.date.stringValue = note.getDateForLabel()
                    }
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
    
    public func enableLockedProject() {
        ViewController.shared()?.lockedFolder.isHidden = false
        usesAlternatingRowBackgroundColors = false
        clean()
    }
    
    public func disableLockedProject() {
        ViewController.shared()?.lockedFolder.isHidden = true
        usesAlternatingRowBackgroundColors = true
    }
    
    public func clean() {
        noteList.removeAll()
        reloadData()
    }
    
    public func doVisualChanges(results: ([Note], [Note], [Note])) {
        guard results.0.count > 0 || results.1.count > 0 || results.2.count > 0 else {
            return
        }
        
        DispatchQueue.main.async {
            self.removeRows(notes: results.0)
            self.insertRows(notes: results.1)
            self.reloadRows(notes: results.2)
        }
    }
}
