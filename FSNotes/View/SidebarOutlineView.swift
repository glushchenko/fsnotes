//
//  SidebarProjectView.swift
//  FSNotes
//
//  Created by Oleksandr Glushchenko on 4/9/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import Cocoa
import Foundation
import Carbon.HIToolbox

class SidebarOutlineView: NSOutlineView,
    NSOutlineViewDelegate,
    NSOutlineViewDataSource {
    
    public var sidebarItems: [Any]? = nil
    public var viewDelegate: ViewController? = nil
    
    public var storage = Storage.shared()
    public var isFirstLaunch = true
    public var selectNote: Note? = nil

    private var selectedSidebarItems: [SidebarItem]?
    private var selectedProjects: [Project]?
    private var selectedTags: [String]?

    private var cellView: SidebarCellView?

    // MARK: Override
    override func rightMouseDown(with event: NSEvent) {
        guard let vc = ViewController.shared() else { return }
        
        let point = convert(event.locationInWindow, from: nil)
        let rowIndex = row(at: point)
        if (rowIndex < 0 || self.numberOfRows < rowIndex) {
            return
        }

        if let item = item(atRow: rowIndex) as? SidebarItem {
            if item.type == .Separator {
                return
            }
        }

        if !selectedRowIndexes.contains(rowIndex) {
            selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
            scrollRowToVisible(rowIndex)
        }

        if rowView(atRow: rowIndex, makeIfNecessary: false) as? SidebarTableRowView != nil {
            window?.makeFirstResponder(self)
            
            if let menu = menu {
                menu.autoenablesItems = false
                
                for item in menu.items {
                    item.isEnabled = vc.processLibraryMenuItems(item, menuId: "folderPopup")
                }
                
                NSMenu.popUpContextMenu(menu, with: event, for: self)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        allowsTypeSelect = false
        delegate = self
        dataSource = self
        registerForDraggedTypes([
            NSPasteboard.PasteboardType(kUTTypeFileURL as String),
            NSPasteboard.note,
            NSPasteboard.project
        ])
        super.draw(dirtyRect)
    }
    
    override func keyDown(with event: NSEvent) {
        // Tab to search
        if event.keyCode == kVK_Tab {
            self.viewDelegate?.search.becomeFirstResponder()
            return
        }

        // Focus on note list
        if event.keyCode == kVK_RightArrow {
            if let fr = NSApp.mainWindow?.firstResponder, let vc = self.viewDelegate, fr.isKind(of: SidebarOutlineView.self) {

                if let tag = item(atRow: selectedRow) as? FSTag, tag.isExpandable(), !isItemExpanded(tag) {
                    super.keyDown(with: event)
                    return
                }

                if let project = item(atRow: selectedRow) as? Project, project.isExpandable(), !isItemExpanded(project) {
                    super.keyDown(with: event)
                    return
                }

                if let project = item(atRow: selectedRow) as? Project, project.isLocked() {
                    toggleFolderLock(NSMenuItem())
                    return
                }
                
                vc.notesTableView.selectCurrent()
                NSApp.mainWindow?.makeFirstResponder(vc.notesTableView)
                return
            }
        }

        super.keyDown(with: event)
    }

    override func expandItem(_ item: Any?, expandChildren: Bool) {
        if let project = item as? Project {
            project.isExpanded = true
        }

        super.expandItem(item, expandChildren: expandChildren)

        storage.saveProjectsExpandState()
    }

    override func collapseItem(_ item: Any?, collapseChildren: Bool) {
        if let project = item as? Project {
            project.isExpanded = false
        }

        super.collapseItem(item, collapseChildren: collapseChildren)

        storage.saveProjectsExpandState()
    }

    override func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        guard let index = indexes.first else { return }

        var extend = extend

        if (item(atRow: index) as? FSTag) != nil {
            for i in selectedRowIndexes {
                if nil != item(atRow: i) as? FSTag {
                    deselectRow(i)
                }
            }

            extend = true
        }

        super.selectRowIndexes(indexes, byExtendingSelection: extend)
    }

    
    // MARK: Delegates

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let vc = ViewController.shared() else { return false }
        guard let sidebarItems = self.sidebarItems else { return false }
        
        // Drag and drop project (reorder)
        if let data = info.draggingPasteboard.string(forType: NSPasteboard.project) {
            let url = URL(fileURLWithPath: data)
            
            guard let project = Storage.shared().getProjectBy(url: url) else { return false }
            
            // Get src index for child and root folders
            var srcIndex: Int?
            let dstProject = item as? Project
            
            if dstProject != nil, let srcParent = project.parent, !srcParent.isDefault {
                srcIndex = srcParent.child.firstIndex(where: { $0 === project })
            } else {
                srcIndex = sidebarItems.firstIndex(where: { $0 as? Project === project })
            }
            
            guard let srcIndex = srcIndex else { return false }

            var diff = 0
            if srcIndex > index {
                diff = 0
            } else {
                diff = -1
            }
            
            outlineView.moveItem(at: srcIndex, inParent: item, to: index + diff, inParent: item)
            
            if item == nil {
                self.sidebarItems?.remove(at: srcIndex)
                self.sidebarItems?.insert(project, at: index + diff)
                
                // Save order
                if let si = self.sidebarItems {
                    var toSave = [Project]()
                    for sidebarItem in si {
                        
                        // Save all projects from this level
                        if let siProject = sidebarItem as? Project, project.parent === siProject.parent
                            || (project.isBookmark && siProject.parent?.isDefault == true)
                            || (project.parent?.isDefault == true && siProject.isBookmark)
                        {
                            toSave.append(siProject)
                        }
                    }
                    saveOrderFor(projects: toSave)
                }
            } else {
                project.parent?.child.remove(at: srcIndex)
                project.parent?.child.insert(project, at: index + diff)
                
                // Save order
                if let projects = project.parent?.child {
                    saveOrderFor(projects: projects)
                }
            }
            
            return true
        }

        // Drag and drop Note
        let board = info.draggingPasteboard

        var urls = [URL]()
        if let data = info.draggingPasteboard.data(forType: NSPasteboard.note),
           let unarchivedData = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSURL.self], from: data) as? [URL] {
            urls = unarchivedData
        }

        // tags
        if let tag = item as? FSTag {
            if urls.count > 0, Storage.shared().getBy(url: urls.first!) != nil {
                for url in urls {
                    if let note = Storage.shared().getBy(url: url) {
                        note.addTag(tag.getFullName())
                        _ = note.scanContentTags()
                        viewDelegate?.notesTableView.reloadRow(note: note)

                        if viewDelegate?.editor.note == note {
                            viewDelegate?.refillEditArea(force: true)
                        }
                    }
                }
            }

            return true
        }

        // projects
        var maybeProject: Project?

        if let sidebarItem = item as? SidebarItem, let sidebarProject = sidebarItem.project {
            maybeProject = sidebarProject
        }

        if let sidebarProject = item as? Project {
            maybeProject = sidebarProject
        }
        
        if let sidebarItem = item as? SidebarItem, sidebarItem.type == .Inbox {
            maybeProject = Storage.shared().getDefault()
        }

        guard let project = maybeProject else { return false }

        if urls.count > 0, Storage.shared().getBy(url: urls.first!) != nil {
            var notes = [Note]()
            for url in urls {
                if let note = Storage.shared().getBy(url: url) {
                    notes.append(note)
                }
            }

            if project.isTrash {
                vc.editor.clear()
                vc.storage.removeNotes(notes: notes) { _ in
                    DispatchQueue.main.async {
                        vc.notesTableView.removeRows(notes: notes)
                    }
                }
            } else {
                vc.moveReq(notes: notes, project: project) { success in
                    guard success else { return }
                }
            }

            return true
        }

        guard let draggedURLs = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }

        for url in draggedURLs {
            var isDirectory = ObjCBool(true)
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue && !url.path.contains(".textbundle") {

                let dirName = url.lastPathComponent
                let dirDst = project.url.appendingPathComponent(dirName)

                if !FileManager.default.fileExists(atPath: dirDst.path) {
                    try? FileManager.default.copyItem(at: url, to: dirDst)
                } else {
                    let alert = NSAlert()
                    alert.alertStyle = .critical

                    let information = NSLocalizedString("Folder with name '%@' already exist", comment: "")
                    alert.informativeText = String(format: information, dirName)
                    alert.runModal()
                }
            } else {
                _ = vc.copy(project: project, url: url)
            }
        }

        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let project = item as? Project, getSidebarTags() == nil else { return nil }

        let item = NSPasteboardItem()
        item.setString(project.url.path, forType: NSPasteboard.project)

        return item
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        if let archivedData = info.draggingPasteboard.string(forType: NSPasteboard.project) {
            let url = URL(fileURLWithPath: archivedData)
            
            guard let project = Storage.shared().getProjectBy(url: url) else {
                return NSDragOperation()
            }
            
            let dstProject = item as? Project

            if isAllowedDropIndex(srcProject: project, dstProject: dstProject, dstIndex: index) {
                return .move
            }

            return NSDragOperation()
        }
        
        let board = info.draggingPasteboard
        var isLocalNote = false
        var urls = [URL]()

        if let archivedData = info.draggingPasteboard.data(forType: NSPasteboard.note),
           let urlsUnarchived = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSURL.self], from: archivedData) as? [URL] {
            urls = urlsUnarchived

            if let url = urls.first, Storage.shared().getBy(url: url) != nil {
                isLocalNote = true
            }
            
            // Disable drag and drop notes between sidebar items
            if index > -1 {
                return NSDragOperation(rawValue: 0)
            }
        }

        if item as? Project != nil || (item as? SidebarItem)?.project != nil {
            return isLocalNote ? .move : .copy
        }

        if item as? FSTag != nil {
            return .copy
        }

        guard let sidebarItem = item as? SidebarItem else { return NSDragOperation() }
        switch sidebarItem.type {
        case .Inbox:
            return .move
        case .Trash:
            if isLocalNote {
                return .move
            }
            break
        case .Separator:
            guard sidebarItem.isSelectable() else { break }
            
            if isLocalNote {
                return .move
            }
            
            if let urls = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], urls.count > 0 {
                return .copy
            }
            break
        default:
            break
        }
        
        return NSDragOperation()
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let tag = item as? FSTag {
            return tag.child.count
        }

        if let project = item as? Project {
            return project.child.count
        }

        if let sidebar = sidebarItems, item == nil {
            return sidebar.count
        }
        
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if let si = item as? SidebarItem {
            if si.type == .Separator {
                return 15
            }

            if si.type == .Header {
                return 50
            }
        }

        return 25
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let tag = item as? FSTag {
            return tag.isExpandable()
        }

        if let project = item as? Project {
            return project.isExpandable()
        }

        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let tag = item as? FSTag {
            return tag.child[index]
        }

        if let project = item as? Project {
            return project.child[index]
        }

        if let sidebar = sidebarItems, item == nil {
            return sidebar[index]
        }
        
        return String()
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        return item
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {

        let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DataCell"), owner: self) as! SidebarCellView

        cell.icon.contentTintColor = NSColor.controlAccentColor

        if let tag = item as? FSTag {
            cell.type = .Tag

            let image = NSImage(named: "sidebar_tag")
            image?.isTemplate = true

            cell.icon.image = image
            cell.icon.isHidden = false
            cell.label.frame.origin.x = 25
            cell.textField?.stringValue = tag.getName()

        } else if let project = item as? Project {

            if project.isEncrypted {
                if project.isLocked() {
                    cell.type = .ProjectEncryptedLocked

                    let image = NSImage(named: "sidebar_project_encrypted_locked")
                    image?.isTemplate = true

                    cell.icon.image = image
                } else {
                    cell.type = .ProjectEncryptedUnlocked

                    let image = NSImage(named: "sidebar_project_encrypted_unlocked")
                    image?.isTemplate = true

                    cell.icon.image = image
                }
            } else {
                cell.type = .Project

                let image = NSImage(named: "sidebar_project")
                image?.isTemplate = true

                cell.icon.image = image
            }
            
            cell.icon.isHidden = false
            cell.label.frame.origin.x = 25
            cell.textField?.stringValue = project.label

        } else if let si = item as? SidebarItem {
            let name = si.type == .Separator ? "" : si.name
            
            cell.textField?.stringValue = name
            cell.type = si.type

            if let name = si.type.icon, let image = si.getIcon(name: name) {
                cell.icon.image = image
            } else {
                cell.icon.image = nil
            }

            cell.icon.isHidden = false
            cell.label.frame.origin.x = 25

            if si.type == .Header {
                let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HeaderCell"), owner: self) as! SidebarHeaderCellView

                cell.label.frame.origin.x = 2
                cell.label.stringValue = name

                return cell
            }
        }

        return cell
    }
    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if nil != item as? FSTag {
            return true
        }

        if nil != item as? Project {
            return true
        }

        if let sidebarItem = item as? SidebarItem {
            return sidebarItem.isSelectable()
        }
        
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return SidebarTableRowView(frame: NSZeroRect)
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        defer {
            isFirstLaunch = false
        }
        
        guard let vd = viewDelegate else { return }
        guard let view = notification.object as? NSOutlineView else { return }

        viewDelegate?.notesTableView.disableLockedProject()
        
        if UserDataService.instance.isNotesTableEscape {
            UserDataService.instance.isNotesTableEscape = false
        }

        let hasChangedSidebarItemsState = isChangedSidebarItemsState()
        let hasChangedProjectsState = isChangedProjectsState()
        let hasChangedTagsState = isChangedTagsState()

        if hasChangedTagsState || hasChangedProjectsState || hasChangedSidebarItemsState {
            vd.editor.clear()
        }

        let i = view.selectedRow

        if UserDefaultsManagement.inlineTags,
            view.item(atRow: i) as? FSTag == nil,
            hasChangedProjectsState || hasChangedSidebarItemsState {

            reloadTags()
        }

        if let item = view.item(atRow: i) as? SidebarItem {
            if UserDefaultsManagement.lastSidebarItem == item.type.rawValue
                && !hasChangedTagsState
                && !isFirstLaunch {
                return
            }

            UserDefaultsManagement.lastSidebarItem = item.type.rawValue
            UserDefaultsManagement.lastProjectURL = nil
        }

        if let selectedProject = view.item(atRow: i) as? Project {
            if UserDefaultsManagement.lastProjectURL == selectedProject.url
                && !hasChangedTagsState
                && !isFirstLaunch {
                return
            }

            UserDefaultsManagement.lastProjectURL = selectedProject.url
            UserDefaultsManagement.lastSidebarItem = nil
            
            if selectedProject.isLocked() {
                viewDelegate?.notesTableView.enableLockedProject()
            }
        }

        if !isFirstLaunch {
            vd.search.stringValue = ""
        }

        guard !UserDataService.instance.skipSidebarSelection else {
            UserDataService.instance.skipSidebarSelection = false
            return
        }

        vd.buildSearchQuery()
        vd.updateTable() {

            if let note = self.selectNote {
                if let i = vd.notesTableView.getIndex(note) {
                    if vd.notesTableView.noteList.indices.contains(i) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            vd.notesTableView.selectRowIndexes([i], byExtendingSelection: false)
                            vd.notesTableView.scrollRowToVisible(i)
                        }
                    }
                }

                self.selectNote = nil
            }
        }
    }

    // MARK: Actions
    @IBAction func revealInFinder(_ sender: Any) {
        guard let projects = getSelectedProjects() else { return }
        
        let urls = projects.map { $0.url }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
    
    @IBAction func renameFolderMenu(_ sender: Any) {
        guard let vc = ViewController.shared(),
              let sidebarOutlineView = vc.sidebarOutlineView else { return }

        if sidebarOutlineView.getSidebarTags() != nil {
            sidebarOutlineView.renameTag(NSMenuItem())
            return
        }

        guard sidebarOutlineView.getSelectedProject() != nil else { return }

        guard let projectRow = sidebarOutlineView.rowView(atRow: sidebarOutlineView.selectedRow, makeIfNecessary: false),
              let cell = projectRow.view(atColumn: 0) as? SidebarCellView else { return }
        
        cell.label.isEditable = true
        cell.label.becomeFirstResponder()
    }

    @IBAction public func removeTags(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }
        guard let window = MainWindowController.shared() else { return }
        guard let selectedTags = vc.sidebarOutlineView.getSidebarTags() else { return }

        let alert = NSAlert()
        vc.alert = alert

        let messageText = NSLocalizedString("Are you really want to remove %d tag(s)? This action can not be undone.", comment: "")

        alert.messageText = NSLocalizedString("Remove Tags", comment: "")
        alert.informativeText = String(format: messageText, selectedTags.count)

        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("Remove", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {

                let notes = vc.notesTableView.noteList
                var plainTags = [String]()
                for index in vc.sidebarOutlineView.selectedRowIndexes {
                    if let tag = vc.sidebarOutlineView.item(atRow: index) as? FSTag {
                        plainTags.append(contentsOf: tag.getAllChild())
                    }
                }

                vc.sidebarOutlineView.remove(tags: plainTags, from: notes)
            }

            NSApp.mainWindow?.makeFirstResponder(vc.sidebarOutlineView)
            vc.alert = nil
        }
    }

    @IBAction func renameTag(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }
        guard let window = MainWindowController.shared() else { return }
        guard let tags = vc.sidebarOutlineView.getRawSidebarTags() else { return }

        let alert = NSAlert()
        vc.alert = alert

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
        if let name = tags.first?.getFullName() {
            field.stringValue = name
        }

        alert.messageText = NSLocalizedString("Rename Tags", comment: "")
        alert.informativeText = NSLocalizedString("Please enter tag name:", comment: "")
        alert.accessoryView = field
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
            if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                let name = field.stringValue.replacingOccurrences(of: "\\s", with: "", options: NSString.CompareOptions.regularExpression, range: nil)
                self.rename(tags: tags, name: name)
            }

            NSApp.mainWindow?.makeFirstResponder(vc.sidebarOutlineView)
            vc.alert = nil
        }

        field.becomeFirstResponder()
    }

    @IBAction func deleteMenu(_ sender: Any) {
        guard let vc = ViewController.shared(),
              let sidebarOutlineView = vc.sidebarOutlineView else { return }

        if sidebarOutlineView.getSidebarTags() != nil {
            sidebarOutlineView.removeTags(NSMenuItem())
            return
        }

        guard let projects = sidebarOutlineView.getSelectedProjects() else { return }

        for project in projects {
            delete(project: project)
        }
    }

    private func delete(project: Project) {
        guard let vc = ViewController.shared() else { return }

        if !(project.isDefault || project.isBookmark) {
            guard let window = MainWindowController.shared() else { return }

            let alert = NSAlert.init()
            vc.alert = alert

            let messageText = NSLocalizedString("Are you sure you want to remove project \"%@\" and all files inside?", comment: "")

            alert.messageText = String(format: messageText, project.label)
            alert.informativeText = NSLocalizedString("This action cannot be undone.", comment: "Delete menu")
            alert.addButton(withTitle: NSLocalizedString("Remove", comment: "Delete menu"))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Delete menu"))
            alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
                if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                    do {
                        try FileManager.default.removeItem(at: project.url)

                        self.storage.cleanCachedTree(url: project.url)
                    } catch {
                        print(error)
                    }

                    NSApp.mainWindow?.makeFirstResponder(vc.sidebarOutlineView)
                }

                vc.alert = nil
            }
            return
        }

        let projects = storage.getAvailableProjects().filter({ $0.url.path.starts(with: project.url.path) })

        for item in projects {
            SandboxBookmark().removeBy(item.url)
        }

        vc.sidebarOutlineView.removeRows(projects: projects)
        vc.sidebarOutlineView.selectRowIndexes([0], byExtendingSelection: false)
        vc.updateTable()
    }
    
    @IBAction func removeFolderEncryption(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared(),
            let projects = vc.sidebarOutlineView.getSelectedProjects() else { return }

        guard let firstProject = projects.first  else { return }

        if firstProject.isEncrypted {
            vc.getMasterPassword() { password in
                vc.sidebarOutlineView.decrypt(projects: projects, password: password)
            }
        }
    }

    @IBAction func toggleFolderLock(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared(),
            let projects = vc.sidebarOutlineView.getSelectedProjects() else { return }

        guard let firstProject = projects.first  else { return }
        
        // Encrypt
        if !firstProject.isEncrypted {
            vc.getMasterPassword(forEncrypt: true) { password in
                vc.sidebarOutlineView.encrypt(projects: projects, password: password)
            }
            
            return
        }
        
        // Lock password exist
        if firstProject.password != nil {
            vc.sidebarOutlineView.lock(projects: projects)

        // Unlock
        } else {
            let action = sender.identifier?.rawValue
            vc.getMasterPassword() { password in
                vc.sidebarOutlineView.unlock(projects: projects, password: password, action: action)
            }
        }
    }

    public func decrypt(projects: [Project], password: String) {
        var decryptedQty = 0
        var total = 0
        for project in projects {
            let notes = project.storage.getNotesBy(project: project)
            total += notes.count

            let decrypted = project.decrypt(password: password)
            decryptedQty = decrypted.count
            self.showTags(notes: decrypted)
        }
        
        DispatchQueue.main.async {
            guard decryptedQty > 0 || total == 0 else {
                self.wrongPassAlert()
                return
            }

            guard let vc = ViewController.shared() else { return }

            vc.notesTableView.disableLockedProject()
            vc.notesTableView.reloadData()
            
            vc.updateTable()
            
            self.reloadData(forRowIndexes: self.selectedRowIndexes, columnIndexes: [0])
        }
    }
    
    public func encrypt(projects: [Project], password: String) {
        for project in projects {
            let encrypted = project.encrypt(password: password)
            self.hideTags(notes: encrypted)
        }
        
        DispatchQueue.main.async {
            guard let vc = ViewController.shared() else { return }
            vc.notesTableView.enableLockedProject()
            
            self.reloadData(forRowIndexes: self.selectedRowIndexes, columnIndexes: [0])
            
            // Lock all editors
            let editors = AppDelegate.getEditTextViews()
            for editor in editors {
                if let evc = editor.editorViewController {
                    evc.refillEditArea()
                }
            }
        }
    }
    
    public func lock(projects: [Project]) {
        guard let vc = ViewController.shared() else { return }
        
        var locked = [Note]()
        for project in projects {
            locked.append(contentsOf: project.lock())
        }
        
        hideTags(notes: locked)
        
        if let selectedProject = getSelectedProject(), projects.contains(selectedProject) {
            vc.notesTableView.enableLockedProject()
            vc.updateTable()
            vc.editor.clear()
        }
        
        for project in projects {
            reloadItem(project)
        }
        
        // Lock all editors
        let editors = AppDelegate.getEditTextViews()
        for editor in editors {
            if let evc = editor.editorViewController {
                evc.refillEditArea()
            }
        }
    }
    
    public func unlock(projects: [Project], password: String, action: String? = nil) {
        var unlocked = [Note]()
        var isEmptyDir = false
        
        for project in projects {
            let result = project.unlock(password: password)

            // no notes
            if result.0.count == 0 {
                isEmptyDir = true
                continue
            }

            unlocked.append(contentsOf: result.1)
        }
        
        self.showTags(notes: unlocked)
        
        DispatchQueue.main.async {
            if unlocked.count > 0 || (projects.count == 1 && isEmptyDir) {
                guard let vc = ViewController.shared() else { return }
                
                vc.notesTableView.disableLockedProject()
                vc.updateTable() {
                    if action == "menu.newNote" {
                        DispatchQueue.main.async {
                            _ = vc.createNote()
                        }
                    }
                }
                
                self.reloadData(forRowIndexes: self.selectedRowIndexes, columnIndexes: [0])
            } else {
                self.wrongPassAlert()
            }
        }
    }
    
    private func wrongPassAlert() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = NSLocalizedString("Wrong password", comment: "")
        alert.beginSheetModal(for: self.window!) { (returnCode: NSApplication.ModalResponse) -> Void in }
    }
    
    private func hideTags(notes: [Note]) {
        var notesTags = [String]()
        for note in notes {
            let tags = note.tags
            note.tags.removeAll()
            for tag in tags {
                if !notesTags.contains(tag) {
                    notesTags.append(tag)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.removeTags(notesTags)
        }
    }
    
    private func showTags(notes: [Note]) {
        var notesTags = [String]()
        for note in notes {
            if note.tags.count == 0 {
                _ = note.scanContentTags().0
            }
            
            for insertTag in note.tags {
                if !notesTags.contains(insertTag) {
                    notesTags.append(insertTag)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.addTags(notesTags)
        }
    }

    // MARK: Functions
    
    private func isAllowedDropIndex(srcProject: Project, dstProject: Project?, dstIndex: Int) -> Bool {
        guard let sidebarItems = self.sidebarItems else { return false }
        
        var srcIndex: Int?
        
        if dstProject != nil, let srcParent = srcProject.parent, !srcParent.isDefault {
            srcIndex = srcParent.child.firstIndex(where: { $0 === srcProject })
        } else {
            srcIndex = sidebarItems.firstIndex(where: { $0 as? Project === srcProject })
        }
        
        guard let srcIndex = srcIndex else { return false }
        
        if srcIndex == dstIndex || srcIndex + 1 == dstIndex {
            return false
        }
        
        // Allow child reordering if parent equal to dst
        if let dstProject = dstProject, dstProject === srcProject.parent {
            return true
        }
        
        if sidebarItems.indices.contains(dstIndex - 1),
            let proposedProject = sidebarItems[dstIndex - 1] as? Project,
           srcProject.parent === proposedProject.parent 
            || (srcProject.isBookmark && proposedProject.parent?.isDefault == true)
            || (srcProject.parent?.isDefault == true && proposedProject.isBookmark)
        {
            return true
        }
        
        if sidebarItems.indices.contains(dstIndex), sidebarItems[dstIndex] as? Project == nil {
            return false
        }
        
        if sidebarItems.indices.contains(dstIndex + 1),
            let proposedProject = sidebarItems[dstIndex + 1] as? Project,
           srcProject.parent === proposedProject.parent 
            || (srcProject.isBookmark && proposedProject.parent?.isDefault == true)
            || (srcProject.parent?.isDefault == true && proposedProject.isBookmark)
        {
            return true
        }

        return false
    }
    
    private func saveOrderFor(projects: [Project]) {
        var i = 0
        for project in projects {
            project.settings.priority = i
            i += 1
            
            project.saveSettings()
        }
    }

    public func removeTags(notes: [Note]) {
        guard let vc = ViewController.shared() else { return }

        var allNoteTags: Set<String> = []
        for note in vc.notesTableView.noteList {
            for tag in note.tags {
                if !allNoteTags.contains(tag) {
                    allNoteTags.insert(tag)
                }
            }
        }

        var allRemoveTags = [String]()
        for note in notes {
            for tag in note.tags {
                allRemoveTags.append(tag)
            }
        }

        var remove = [String]()
        for tag in allRemoveTags {
            if !allNoteTags.contains(tag) {
                remove.append(tag)
            }
        }

        removeTags(remove)
    }

    public func insertTags(note: Note) {
        var tags = [String]()
        for tag in note.tags {
            if !tags.contains(tag) {
                tags.append(tag)
            }
        }

        var sTags: Set<String> = []
        if let allSidebarTags = sidebarItems?.filter({ ($0 as? FSTag) != nil }).map({ ($0 as? FSTag)!.getFullName() }) {
            sTags = Set(allSidebarTags)
        }

        var insert = [String]()
        for tag in tags {
            if !sTags.contains(tag) {
                insert.append(tag)
            }
        }

        addTags(insert)
    }

    private func isChangedSidebarItemsState() -> Bool {
        let sidebarItems = getSidebarItems()
        let selectedItems = selectedSidebarItems

        selectedSidebarItems = sidebarItems

        if let current = sidebarItems, let selected = selectedItems {
            for item in current {
                if !selected.contains(where: { $0 === item }) {
                    return true
                }
            }

            return false
        }

        return sidebarItems?.count != selectedItems?.count
    }

    private func isChangedProjectsState() -> Bool {
        let sidebarProjects = getSelectedProjects()
        let selectedItems = selectedProjects

        selectedProjects = sidebarProjects

        if let current = sidebarProjects, let selected = selectedItems {
            for item in current {
                if !selected.contains(where: { $0 === item }) {
                    return true
                }
            }

            return false
        }

        return sidebarProjects?.count != selectedItems?.count
    }

    private func isChangedTagsState() -> Bool {
        let sidebarTags = getSidebarTags()
        let selectedItems = selectedTags

        selectedTags = sidebarTags

        if let current = sidebarTags, let selected = selectedTags {
            for item in current {
                if !selected.contains(item) {
                    return true
                }
            }

            return false
        }

        return sidebarTags?.count != selectedItems?.count
    }

    public func remove(project: Project) {
        selectedProjects?.removeAll(where: { $0 === project })

        if UserDataService.instance.lastProject?.path == project.url.path {
            self.viewDelegate?.cleanSearchAndEditArea()
            selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        storage.cleanCachedTree(url: project.url)
        storage.removeBy(project: project)

        guard let vc = ViewController.shared(), vc.isVisibleSidebar() else { return }
        
        if let parent = project.parent, !parent.isDefault {
            if let index = parent.child.firstIndex(of: project) {
                parent.child.removeAll(where: { $0 == project })
                removeItems(at: [index], inParent: parent, withAnimation: .effectFade)
                reloadItem(parent)
            }
        } else {
            if let index = sidebarItems?.firstIndex(where: { ($0 as? Project) == project }) {
                sidebarItems?.remove(at: index)
                removeItems(at: [index], inParent: nil, withAnimation: .effectFade)
            }
        }
    }
    
    public func insertRows(projects: [Project]) {
        for project in projects {
            insert(project: project)
        }
        
        storage.loadProjectRelations()
    }
    
    public func removeRows(projects: [Project]) {
        
        // Append and remove childs too if exist
        var projects = projects
        for item in projects {
            let child = item.getChildProjectsByURL()
            for childItem in child {
                
                // No project with url
                if projects.first(where: { $0.url.path == childItem.url.path }) == nil {
                    projects.append(childItem)
                }
            }
        }
        
        for project in projects {
            
            // Remove notes from NoteTableView
            let notes = project.getNotes()
            viewDelegate?.notesTableView.removeRows(notes: notes)
            
            // Remove projects from SidebarOutlineView
            remove(project: project)
        }
        
        storage.loadProjectRelations()
    }
    
    public func insert(project: Project) {
        guard let vc = ViewController.shared(),
              vc.isVisibleSidebar(),
              let lastProjectIndex = vc.sidebarOutlineView.getProjectsSeparatorPosition() else { return }

        if let parent = storage.findParent(url: project.url) {
            if parent.isDefault {
                let offset = lastProjectIndex + countProjects() + 1
                vc.sidebarOutlineView.sidebarItems?.insert(project, at: offset)
                vc.sidebarOutlineView.insertItems(at: [offset], inParent: nil, withAnimation: .effectFade)
            } else {
                if parent.child.filter({ $0.url == project.url }).count == 0 {
                    parent.child.insert(project, at: 0)
                    vc.sidebarOutlineView.insertItems(at: [0], inParent: parent, withAnimation: .effectFade)
                }
                
                vc.sidebarOutlineView.reloadItem(parent)

            }
        } else {
            let offset = lastProjectIndex + countProjects() + 1
            vc.sidebarOutlineView.sidebarItems?.insert(project, at: offset)
            vc.sidebarOutlineView.insertItems(at: [offset], inParent: nil, withAnimation: .effectFade)
        }
        
        viewDelegate?.fsManager?.reloadObservedFolders()
    }
        
    public func addRoot() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.begin { (result) -> Void in
            if result == .OK {
                guard let url = openPanel.url else { return }
                
                let bookmarksManager = SandboxBookmark.sharedInstance()
                bookmarksManager.store(url: url)
                bookmarksManager.save()
                
                if let results = self.storage.insert(url: url, bookmark: true) {
                    self.insertRows(projects: results)
                    
                    if let vc = self.viewDelegate {
                        vc.fsManager?.restart()
                    }
                }
            }
        }
    }

    public func getSidebarItems() -> [SidebarItem]? {
        var items = [SidebarItem]()

        for i in selectedRowIndexes {
            if let project = item(atRow: i) as? SidebarItem {
                items.append(project)
            }
        }

        return items
    }

    public func getSidebarProjects() -> [Project]? {
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return nil }

        var projects = [Project]()
        for i in v.selectedRowIndexes {
            if let si = item(atRow: i) as? SidebarItem, let project = si.project, !project.isVirtual, si.tag == nil {
                projects.append(project)
            }
        }

        for i in v.selectedRowIndexes {
            if let project = item(atRow: i) as? Project {
                projects.append(project)
            }
        }

        for project in projects {
            if project.settings.showNestedFoldersContent, !project.isEncrypted, let child = project.getAllChild() {
                for item in child {
                    if !projects.contains(item) {
                        projects.append(item)
                    }
                }
            }
        }

        if projects.count > 0 {
            return projects
        }

        return nil
    }

    public func getSidebarTags() -> [String]? {
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return nil }

        var tags = [String]()
        for i in v.selectedRowIndexes {
            if let tag = (item(atRow: i) as? FSTag)?.getFullName() {
                tags.append(tag)
            }
        }

        if tags.count > 0 {
            return tags
        }

        return nil
    }

    public func getRawSidebarTags() -> [FSTag]? {
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return nil }

        var tags = [FSTag]()
        for i in v.selectedRowIndexes {
            if let tag = (item(atRow: i) as? FSTag) {
                tags.append(tag)
            }
        }

        if tags.count > 0 {
            return tags
        }

        return nil
    }

    public func getSelectedInlineTags() -> String {
        var inlineTags = String()
        if let tags = getSidebarTags() {
            for tag in tags {
                inlineTags += "#\(tag) "
            }
        }
        return inlineTags
    }

    public func selectNext() {
        let i = selectedRow + 1
        guard let si = sidebarItems, si.indices.contains(i) else { return }

        if let next = si[i] as? SidebarItem {
            if next.type == .Separator && next.project == nil {
                let j = i + 1

                guard let si = sidebarItems, si.indices.contains(j) else { return }

                if let next = si[j] as? SidebarItem, next.type != .Separator {
                    selectRowIndexes([j], byExtendingSelection: false)
                    return
                }

                return
            }
        }

        selectRowIndexes([i], byExtendingSelection: false)
    }

    public func selectPrev() {
        let i = selectedRow - 1
        guard let si = sidebarItems, si.indices.contains(i) else { return }

        if let next = si[i] as? SidebarItem {
            if next.type == .Separator && next.project == nil {
                let j = i - 1

                guard let si = sidebarItems, si.indices.contains(j) else { return }

                if let next = si[j] as? SidebarItem, next.type != .Separator {
                    selectRowIndexes([j], byExtendingSelection: false)
                    return
                }

                return
            }
        }

        selectRowIndexes([i], byExtendingSelection: false)
    }

    public func getSelectedProject() -> Project? {
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return nil }

        if let project = v.item(atRow: v.selectedRow) as? Project {
            return project
        }

        if let sidebarItem = v.item(atRow: v.selectedRow) as? SidebarItem {
            if sidebarItem.type == .Inbox {
                return vc.storage.getDefault()
            }
            
            if let project = sidebarItem.project {
                return project
            }
        }

        return nil
    }

    public func getSelectedProjects() -> [Project]? {
        var items = [Project]()

        for i in selectedRowIndexes {
            if let project = item(atRow: i) as? Project {
                items.append(project)
            }
        }

        return items
    }

    private func getSelectedProjectsIndexes() -> [Int]? {
        var items = [Int]()

        for i in selectedRowIndexes {
            if item(atRow: i) as? Project != nil {
                items.append(i)
            }
        }

        return items
    }
    
    @objc public func reloadSidebar() {
        guard let vc = ViewController.shared() else { return }

        vc.fsManager?.reloadObservedFolders()
        vc.loadMoveMenu()

        let selected = vc.sidebarOutlineView.selectedRow
        vc.sidebarOutlineView.sidebarItems = Sidebar().getList()
        vc.sidebarOutlineView.reloadData()
        vc.sidebarOutlineView.selectRowIndexes([selected], byExtendingSelection: false)

        if let project = getSelectedProject(), project.isLocked() {
            vc.notesTableView.enableLockedProject()
        }

        vc.sidebarOutlineView.loadAllTags()
    }
    
    public func deselectAllTags() {
        guard let items = self.sidebarItems?.filter({($0 as? FSTag) != nil}) else { return }
        for item in items {
            let i = self.row(forItem: item)
            guard i > -1 else { continue }

            if let row = self.rowView(atRow: i, makeIfNecessary: false), let cell = row.view(atColumn: 0) as? SidebarCellView {
                cell.icon.image = NSImage(named: "sidebar_tag")
            }
        }
    }

    public func selectSidebar(type: SidebarItemType) {
        if let i = sidebarItems?.firstIndex(where: {($0 as? SidebarItem)?.type == type }) {
            selectRowIndexes([i], byExtendingSelection: false)
        }
    }

    public func selectSidebarRoot() {
        if let i = sidebarItems?.firstIndex(where: { ($0 as? Project)?.isDefault == true }) {
            selectRowIndexes([i], byExtendingSelection: false)
        }
    }

    public func select(note: Note) {
        let sidebarItem = sidebarItems?.first(where: {($0 as? SidebarItem)?.project == note.project || $0 as? Project == note.project })

        var index = row(forItem: sidebarItem)
        if (index == -1) {
            var expandQueue = [Project]()
            var project = note.project
            
            while let parent = project.parent, isExpandable(parent) {
                project = parent
                expandQueue.append(project)
            }
            
            for item in expandQueue.reversed() {
                expandItem(item)
            }
            
            index = row(forItem: note.project)
        }

        if index > -1 {
            selectNote = note
            scrollRowToVisible(index)
            selectRowIndexes([index], byExtendingSelection: false)
            return
        }
    }
    
    public func remove(tag: FSTag) {
        if let i = sidebarItems?.firstIndex(where: { ($0 as? FSTag) === tag }) {
            self.removeItems(at: [i], inParent: nil, withAnimation: [])
            sidebarItems?.remove(at: i)
        }
    }

    public func remove(tagName: String) {
        let tags = tagName.components(separatedBy: "/")
        guard let parent = tags.first else { return }
        
        if let vc = ViewController.shared(), !vc.isVisibleSidebar() {
            return
        }

        if let tag = sidebarItems?.first(where: {($0 as? FSTag)?.getName() == parent }) as? FSTag {
            if tags.count == 1 {
                let allTags = ViewController.shared()?.sidebarOutlineView.getAllTags()
                let count = allTags?.filter({ $0.starts(with: parent + "/") || $0 == parent }).count ?? 0

                if count == 0 {
                    if let index = sidebarItems?.firstIndex(where: { ($0 as? FSTag)?.getName() == parent }) {
                        removeItems(at: [index], inParent: nil, withAnimation: [])
                        sidebarItems?.remove(at: index)
                    }
                }
            } else if var foundTag = tag.find(name: tagName) {
                while let parent = foundTag.getParent() {
                    if let i = parent.indexOf(child: foundTag) {
                        removeItems(at: [i], inParent: parent, withAnimation: [])
                        parent.remove(by: i)
                    }

                    if
                        parent.getParent() == nil
                        && parent.child.count == 0,
                        let i = sidebarItems?.firstIndex(where: { ($0 as? FSTag)?.getName() == parent.getName() })
                    {
                        if isAllowTagRemoving(parent.getName()) {
                            removeItems(at: [i], inParent: nil, withAnimation: [])
                            sidebarItems?.remove(at: i)
                        }

                        break
                    }

                    foundTag = parent
                }
            }
        }
    }

    public func addTags(_ tags: [String], shouldUnloadOld: Bool = false) {
        guard tags.count > 0 else {
            unloadAllTags()
            return
        }
        
        beginUpdates()

        if shouldUnloadOld {
            unloadAllTags()
        }

        for tag in tags {
            addTag(tag: tag)
        }

        endUpdates()
    }

    public func removeTags(_ tags: [String]) {
        var removeTags = [String]()

        for tag in tags {
            if isAllowTagRemoving(tag) {
                removeTags.append(tag)
            }
        }

        beginUpdates()
        for tag in removeTags {
            remove(tagName: tag)
        }
        endUpdates()
    }

    public func isAllowTagRemoving(_ name: String) -> Bool {
        let tags = getAllTags()
        var allow = true

        for tag in tags {
            if tag.starts(with: name + "/") || tag == name {
                allow = false
            }
        }

        return allow
    }

    public func reloadTags() {
        if UserDefaultsManagement.inlineTags {
            loadAllTags()
        }
    }

    public func unloadAllTags() {
        if let tags = sidebarItems?.filter({ ($0 as? FSTag) != nil && ($0 as? FSTag)?.getParent()
             == nil }) as? [FSTag] {
            beginUpdates()
            for tag in tags {
                remove(tag: tag)
            }
            endUpdates()
        }
    }

    public func getAllTags() -> [String] {
        var tags: Set<String> = []
        var projects: [Project]? = getSidebarProjects()
        let selectedItem = item(atRow: selectedRow) as? SidebarItem


        if selectedItem?.type == .All || projects == nil {
            projects = storage.getProjects().filter({ !$0.isTrash && $0.settings.showInCommon })
        }

        if let projects = projects {
            for project in projects {
                let projectTags = project.getAllTags()
                for tag in projectTags {
                    if !tags.contains(tag) {
                        tags.insert(tag)
                    }
                }
            }
        }

        return Array(tags)
    }

    public func loadAllTags() {
        let tags = getAllTags()

        addTags(tags.sorted(), shouldUnloadOld: true)
    }

    public func select(tag: String) {
        let fullTags = tag.split(separator: "/").map(String.init);
        var items = sidebarItems;
        var tagDepth: Int = 0
        var selectedIndexes = getSelectedProjectsIndexes() ?? [tagDepth]

        let currentNote = viewDelegate?.editor.note
        selectNote = currentNote

        for tagIndex in 0..<fullTags.count{
            guard let tag = items?.first(where: {($0 as? FSTag)?.getName() == fullTags[tagIndex]}) as? FSTag else { break }
            var index = row(forItem: tag)

            if index < 0 {
                index = items?.firstIndex(where: {($0 as? FSTag)?.getName() == fullTags[tagIndex]}) ?? 0
                tagDepth += index + 1
            } else {
                tagDepth = index
            }

            expandItem(item(atRow: tagDepth))
            scrollRowToVisible(tagDepth)

            items = tag.child
        }

        if !selectedIndexes.contains(tagDepth) {
            selectedIndexes.append(tagDepth)
        }

        super.selectRowIndexes(IndexSet(selectedIndexes), byExtendingSelection: false)
    }
        
    // select and open rowIndexes
    func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool, _ tagIndexArr : [Int]) {
        guard let index = indexes.first else { return }

        var extend = extend

        if (item(atRow: index) as? FSTag) != nil {
            for i in selectedRowIndexes {
                if nil != item(atRow: i) as? FSTag {
                    deselectRow(i)
                }
            }
            extend = true
        }

        tagIndexArr.forEach { tagIndex in
            self.expandItem(item(atRow: tagIndex))
        }

        super.selectRowIndexes(indexes, byExtendingSelection: extend)
    }

    public func addTag(tag: String) {
        guard let vc = ViewController.shared(), vc.isVisibleSidebar() else { return }
        
        var subtags = tag.components(separatedBy: "/")
        let firstLevelName = subtags.first

        if var tag = sidebarItems?.first(where: { ($0 as? FSTag)?.name == firstLevelName }) as? FSTag {
            guard subtags.count > 1 else { return }

            while subtags.count > 0 {
                subtags = Array(subtags.dropFirst())

                tag.addChild(name: subtags.joined(separator: "/"), completion: { (tagItem, isExist, position) in
                    tag = tagItem

                    if !isExist {
                        insertItems(at: [position], inParent: tagItem.getParent(), withAnimation: [])
                    }
                })

                guard subtags.count > 1 else { break }
            }

            return
        }

        let rootTag = FSTag(name: tag)
        let position = getRootTagPosition(for: rootTag)
        sidebarItems?.insert(rootTag, at: position)
        self.insertItems(at: [position], inParent: nil, withAnimation: [])
    }

    public func getRootTagPosition(for tag: FSTag) -> Int {
        guard let offset = sidebarItems?.firstIndex(where: { ($0 as? FSTag) != nil }) else {
            return sidebarItems?.count ?? 0
        }

        guard var tags = sidebarItems?.filter({ $0 as? FSTag != nil }) as? [FSTag] else {
            return sidebarItems?.count ?? 0
        }

        tags.append(tag)

        let sorted = tags.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
        if let index = sorted.firstIndex(where: { $0 === tag }) {
            return index + offset
        }

        return sidebarItems?.count ?? 0
    }
    
    public func getTagsSeparatorPosition() -> Int? {
        return sidebarItems?.firstIndex(where: { ($0 as? SidebarItem)?.type == .Separator && ($0 as? SidebarItem)?.name == "tags" })
    }
    
    public func getProjectsSeparatorPosition() -> Int? {
        return sidebarItems?.firstIndex(where: { ($0 as? SidebarItem)?.type == .Separator && ($0 as? SidebarItem)?.name == "projects" })
    }
    
    public func countProjects() -> Int {
        return sidebarItems?.filter({ ($0 as? Project) != nil }).count ?? 0
    }
        
    public func deleteRoot(tag: String) {
        guard let vc = ViewController.shared(), vc.isVisibleSidebar() else { return }
        
        let subtags = tag.components(separatedBy: "/")

        if let sidebarIndex = sidebarItems?.firstIndex(where: { ($0 as? FSTag)?.name == subtags.first }) {
            sidebarItems?.remove(at: sidebarIndex)
            removeItems(at: [sidebarIndex], inParent: nil, withAnimation: [])
        }
    }

    public func remove(tags: [String], from notes: [Note]) {
        guard let notesTableView = viewDelegate?.notesTableView else { return }

        for note in notes {
            for tagName in tags.reversed() {
                note.delete(tag: "#\(tagName)")
                note.tags.removeAll(where: { $0 == tagName })
                _ = note.scanContentTags()
            }

            DispatchQueue.main.async {
                notesTableView.reloadRow(note: note)
            }
        }

        if let vc = ViewController.shared(), vc.isVisibleSidebar() {
            beginUpdates()
            for index in selectedRowIndexes.reversed() {
                if let tag = item(atRow: index) as? FSTag {
                    if let parentTag = tag.getParent() {
                        if let childIndex = tag.getParent()?.child.firstIndex(where: { $0 === tag }) {
                            tag.parent?.removeChild(tag: tag)
                            removeItems(at: [childIndex], inParent: parentTag, withAnimation: [])
                        }
                    } else if let sidebarIndex = sidebarItems?.firstIndex(where: { ($0 as? FSTag) === tag }) {
                        sidebarItems?.remove(at: sidebarIndex)
                        removeItems(at: [sidebarIndex], inParent: nil, withAnimation: [])
                    }
                }
            }
            endUpdates()
        }
        
        viewDelegate?.editor.clear()
    }

    public func rename(tags: [FSTag], name: String) {
        guard let notesTableView = viewDelegate?.notesTableView else { return }
        let notes = notesTableView.noteList

        let originalName = name.starts(with: "#") ? String(name.dropFirst()) : name
        let name = name.starts(with: "#") ? name : "#\(name)"

        var insertTags = [String]()
        var deleteTags = [String]()

        // get all root deleted tags and all inserted from roots combined with renamed
        for tag in tags {
            let tagNameOriginal = tag.getFullName()
            var fullName = tagNameOriginal
            let firstLevel = fullName.components(separatedBy: "/").first ?? fullName
            deleteTags.append(fullName)

            let allTags = getAllTags()

            // select all started from "#search/level/" or equal "#search/level"
            let related = allTags.filter({ $0.starts(with: fullName + "/") || $0 == fullName })

            // select all started i.e. "#search/yyy" but NOT "#search/level/" and "#search/level"
            let relatedAdditional = allTags.filter({
                $0.starts(with: firstLevel + "/")
                && !$0.starts(with: fullName + "/")
                && $0 != fullName
            })

            // rename related
            for item in related {
                fullName = item
                guard let range = fullName.range(of: tagNameOriginal) else { continue }

                if range.lowerBound.utf16Offset(in: tagNameOriginal) == 0 {
                    fullName.replaceSubrange(range, with: originalName)
                }

                insertTags.append(fullName)
            }

            // and add additional
            for item in relatedAdditional {
                insertTags.append(item)
            }
        }

        // rename tags in notes
        for note in notes {
            for tag in tags {

                // rename and rescan tags ended with empty space separators or slash and skip with chars
                let tagName = tag.getFullName()
                note.replace(tag: "#\(tagName)", with: name)
                note.tags.removeAll(where: { $0 == tagName })
                _ = note.scanContentTags()

                // reload view in notes list
                DispatchQueue.main.async {
                    notesTableView.reloadRow(note: note)
                }
            }
        }

        // update view
        beginUpdates()

        for tag in deleteTags {
            deleteRoot(tag: tag)
        }

        for tag in insertTags {
            addTag(tag: tag)
        }

        endUpdates()

        // select inserted
        if let tag = insertTags.first?.components(separatedBy: "/").first {
            if let tag = sidebarItems?.first(where: { ($0 as? FSTag)?.name == tag }) {
                let index = row(forItem: tag)

                scrollRowToVisible(index)
                selectRowIndexes([index], byExtendingSelection: true)
            }
        }
    }
    
    public func deselectAllRows() {
        UserDefaultsManagement.lastSidebarItem = nil
        UserDefaultsManagement.lastProjectURL = nil
        
        deselectAll(nil)
    }

    public func getNotesProject() -> Project? {
        let item = sidebarItems?.first(where: {
            ($0 as? SidebarItem)?.type == .All
        }) as? SidebarItem

        return item?.project
    }
}
