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

import FSNotesCore_macOS

class SidebarOutlineView: NSOutlineView,
    NSOutlineViewDelegate,
    NSOutlineViewDataSource,
    NSMenuItemValidation {
    
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
        let point = convert(event.locationInWindow, from: nil)
        let rowIndex = row(at: point)
        if (rowIndex < 0 || self.numberOfRows < rowIndex) {
            return
        }

        if !selectedRowIndexes.contains(rowIndex) {
            selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
            scrollRowToVisible(rowIndex)
        }

        if rowView(atRow: rowIndex, makeIfNecessary: false) as? SidebarTableRowView != nil {
            if let menu = menu {
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
            NSPasteboard.noteType,
            NSPasteboard.projectType
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

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        if (clickedRow > -1) {
            //selectRowIndexes([clickedRow], byExtendingSelection: false)

            for item in menu.items {
                item.isHidden = !validateMenuItem(item)
            }
        }
    }

    // MARK: Delegates

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let id = menuItem.identifier?.rawValue else {
            return false
        }

        let tags = ViewController.shared()?.sidebarOutlineView.getSidebarTags()
        let project = ViewController.shared()?.sidebarOutlineView.getSelectedProject()

        if ["context.folder.renameTag", "folder.renameTag", "folder.removeTags"].contains(id) {
            if tags == nil {
                menuItem.isHidden = true
                return false
            }

            menuItem.isHidden = false
            return true
        }

        if id == "folderMenu.attach" {
            return true
        }

        if id == "folderMenu.backup" || id == "context.folderMenu.backup" {
            if tags != nil || project == nil {
                menuItem.isHidden = true
                return false
            }

            if let project = project, project.isTrash {
                menuItem.isHidden = true
                return false
            }

            menuItem.isHidden = false
            return true
        }

        if id == "folderMenu.reveal" {
            if tags != nil || project == nil {
                menuItem.isHidden = true
                return false
            }

            menuItem.isHidden = false
            return true
        }

        if id == "folderMenu.rename" {
            if tags == nil && project == nil {
                menuItem.isHidden = true
                return false
            }

            if let project = project,
                project.isTrash
                || project.isArchive
                || project.isDefault
                || project.isRoot
            {
                menuItem.isHidden = true
                return false
            }

            menuItem.title = tags != nil
                ? NSLocalizedString("Rename Tag", comment: "")
                : NSLocalizedString("Rename Folder", comment: "")

            menuItem.isHidden = false
            return true
        }

        if id == "folderMenu.delete" {
            if tags == nil && project == nil {
                menuItem.isHidden = true
                return false
            }

            if tags != nil {
                menuItem.isHidden = false
                menuItem.title = NSLocalizedString("Delete Tag", comment: "")
                return true
            }

            if let project = project,
                project.isTrash
                || project.isArchive
                || project.isDefault
            {
                menuItem.isHidden = true
                return false
            }

            if let project = project {
                menuItem.title = project.isRoot
                    ? NSLocalizedString("Detach storage", comment: "")
                    : NSLocalizedString("Delete Folder", comment: "")
            }

            menuItem.isHidden = false
            return true
        }
        
        if id == "folderMenu.toggleEncryption" || id == "folderMenubar.toggleEncryption" {
            if let project = project, !project.isArchive, !project.isTrash, !project.isDefault {
                menuItem.title = project.isEncrypted
                    ? NSLocalizedString("Decrypt", comment: "")
                    : NSLocalizedString("Encrypt", comment: "")
                
                menuItem.isHidden = false
                return true
            } else {
                menuItem.isHidden = true
                return false
            }
        }
        
        if id == "folderMenu.toggleLock" || id == "folderMenubar.toggleLock" {
            if let project = project, project.isEncrypted {
                menuItem.title = project.isLocked()
                    ? NSLocalizedString("Unlock", comment: "")
                    : NSLocalizedString("Lock", comment: "")
                
                menuItem.isHidden = false
                return true
            }
        }

        if id == "folderMenu.options" {
            if tags != nil || project == nil {
                menuItem.isHidden = true
                return false
            }

            if let project = project, project.isTrash {
                menuItem.isHidden = true
                return false
            }

            menuItem.isHidden = false
            return true
        }

        if id == "folderMenu.new" {
            if tags != nil || project == nil {
                menuItem.isHidden = true
                return false
            }

            if let project = project, project.isTrash || project.isArchive {
                menuItem.isHidden = true
                return false
            }

            menuItem.isHidden = false
            return true
        }

        menuItem.isHidden = true
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let vc = ViewController.shared() else { return false }
        guard let sidebarItems = self.sidebarItems else { return false }
        
        // Drag and drop project (reorder)
        if let data = info.draggingPasteboard.string(forType: NSPasteboard.projectType) {
            let url = URL(fileURLWithPath: data)
            
            guard let project = Storage.shared().getProjectBy(url: url) else { return false }
            
            // Get src index for child and root folders
            var srcIndex: Int?
            let dstProject = item as? Project
            
            if dstProject != nil, let srcParent = project.parent, !srcParent.isRoot || srcParent.isExternal {
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
                        if let siProject = sidebarItem as? Project, project.parent === siProject.parent {
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
        if let data = info.draggingPasteboard.data(forType: NSPasteboard.noteType),
           let unarchivedData = NSKeyedUnarchiver.unarchiveObject(with: data) as? [URL] {
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
                        vc.notesTableView.removeByNotes(notes: notes)
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
        item.setString(project.url.path, forType: NSPasteboard.projectType)

        return item
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        if let archivedData = info.draggingPasteboard.string(forType: NSPasteboard.projectType) {
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

        if let archivedData = info.draggingPasteboard.data(forType: NSPasteboard.noteType),
           let urlsUnarchived = NSKeyedUnarchiver.unarchiveObject(with: archivedData) as? [URL] {
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
        case .Trash:
            if isLocalNote {
                return .move
            }
            break
        case .Label, .Archive:
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
            if si.type == .Label {
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

        if let tag = item as? FSTag {
            cell.type = .Tag
            cell.icon.image = NSImage(named: "sidebar_tag")
            cell.icon.isHidden = false
            cell.label.frame.origin.x = 25
            cell.textField?.stringValue = tag.getName()

        } else if let project = item as? Project {

            if project.isEncrypted {
                if project.isLocked() {
                    cell.type = .ProjectEncryptedLocked
                    cell.icon.image = NSImage(named: "sidebar_project_encrypted_locked")
                } else {
                    cell.type = .ProjectEncryptedUnlocked
                    cell.icon.image = NSImage(named: "sidebar_project_encrypted_unlocked")
                }
            } else {
                cell.type = .Project
                cell.icon.image = NSImage(named: "sidebar_project")
            }
            
            cell.icon.isHidden = false
            cell.label.frame.origin.x = 25
            cell.textField?.stringValue = project.label

        } else if let si = item as? SidebarItem {
            cell.textField?.stringValue = si.name
            cell.type = si.type
            cell.icon.image = si.type.getIcon()
            cell.icon.isHidden = false
            cell.label.frame.origin.x = 25

            if si.type == .Header {
                let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HeaderCell"), owner: self) as! SidebarHeaderCellView

                cell.label.frame.origin.x = 2
                cell.label.stringValue = si.name
                //cell.icon.image = si.icon?.tint(color: .gray)

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
            storage.isFinishedTagsLoading,
            hasChangedProjectsState || hasChangedSidebarItemsState {

            reloadTags()
        }

        if let item = view.item(atRow: i) as? SidebarItem {
            if UserDefaultsManagement.lastSidebarItem == item.type.rawValue
                && !hasChangedTagsState && !isFirstLaunch {
                return
            }

            UserDefaultsManagement.lastSidebarItem = item.type.rawValue
            UserDefaultsManagement.lastProjectURL = nil
        }

        if let selectedProject = view.item(atRow: i) as? Project {
            if UserDefaultsManagement.lastProjectURL == selectedProject.url && !hasChangedTagsState && !isFirstLaunch {
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

        vd.updateTable() {
            if self.isFirstLaunch {
                DispatchQueue.main.async {
                    vd.restoreOpenedWindows()
                    self.isFirstLaunch = false
                }
            }

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
        guard let project = getSelectedProject() else { return }

        NSWorkspace.shared.selectFile(project.url.path, inFileViewerRootedAtPath: project.url.deletingLastPathComponent().path)
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
        cell.label.textColor = NSColor(named: "color_not_selected")!
        cell.label.becomeFirstResponder()
    }

    @IBAction func openProjectViewSettings(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else {
            return
        }

        if let controller = vc.storyboard?.instantiateController(withIdentifier: "ProjectSettingsViewController")
            as? ProjectSettingsViewController {
                vc.projectSettingsViewController = controller

            if let project = vc.getSidebarProject() {
                vc.presentAsSheet(controller)
                controller.load(project: project)
            }
        }
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

        guard let project = sidebarOutlineView.getSelectedProject() else { return }

        if !project.isRoot {
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
                    } catch {
                        print(error)
                    }

                    NSApp.mainWindow?.makeFirstResponder(sidebarOutlineView)
                }

                vc.alert = nil
            }
            return
        }

        let projects = storage.getAvailableProjects().filter({ $0.url.path.starts(with: project.url.path) })

        for item in projects {
            SandboxBookmark().removeBy(item.url)
            sidebarOutlineView.removeProject(project: item)
        }

        selectRowIndexes([0], byExtendingSelection: false)
        vc.notesTableView.reloadData()

        // Remove unused header
        if vc.isVisibleSidebar(), storage.getExternalProjects().count == 0 {
            let name = NSLocalizedString("External Folders", comment: "")
            if let index = sidebarItems?.firstIndex(where: {
                ($0 as? SidebarItem)?.type == .Header &&
                ($0 as? SidebarItem)?.name == name
            }) {

                sidebarItems?.remove(at: index)
                removeItems(at: [index], inParent: nil, withAnimation: .effectFade)
            }
        }
    }

    @IBAction func addProject(_ sender: Any) {
        guard let vc = ViewController.shared(),
              let sidebarOutlineView = vc.sidebarOutlineView else { return }

        var project = sidebarOutlineView.getSelectedProject()

        if sender is NSMenuItem,
            let mi = sender as? NSMenuItem,
            mi.title == NSLocalizedString("Add External Folder...", comment: "") {
            project = nil
        }
        
        if sender is SidebarCellView, let cell = sender as? SidebarCellView {
            if let objectProject = cell.objectValue as? Project {
                project = objectProject
            } else {
                addRoot()
                return
            }
        }
      
        if let project = project {
          guard let window = MainWindowController.shared() else { return }
          
          let alert = NSAlert()
          vc.alert = alert

          let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 20))
          alert.messageText = NSLocalizedString("New project", comment: "")
          alert.informativeText = NSLocalizedString("Please enter project name:", comment: "")
          alert.accessoryView = field
          alert.alertStyle = .informational
          alert.addButton(withTitle: NSLocalizedString("Add", comment: ""))
          alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
          alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in
              if returnCode == NSApplication.ModalResponse.alertFirstButtonReturn {
                  let name = field.stringValue
                  self.createProject(name: name, parent: project)
              }

              NSApp.mainWindow?.makeFirstResponder(sidebarOutlineView)
              vc.alert = nil
          }
          
          field.becomeFirstResponder()
        } else {
          addRoot()
        }
    }

    @IBAction func openSettings(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared() else { return }

        vc.sidebarOutlineView.openProjectViewSettings(sender)
    }

    @IBAction func makeSnapshot(_ sender: NSMenuItem) {
        guard let window = self.window else { return }
        guard let project = ViewController.shared()?.getSidebarProject() else { return }

        ViewController.gitQueue.addOperation({
            ViewController.gitQueueOperationDate = Date()

            defer {
                ViewController.gitQueueOperationDate = nil
            }

            guard let project = project.getGitProject() else { return }
            
            do {
                try project.commit()
                
                // No hands – no mults
                guard project.getGitOrigin() != nil else { return }
                
                try project.pull()
                try project.push()
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.alertStyle = .critical
                    alert.informativeText = NSLocalizedString("Git error", comment: "")
                    alert.messageText = error.localizedDescription
                    alert.beginSheetModal(for: window) { (returnCode: NSApplication.ModalResponse) -> Void in }
                }
            }
        })
    }
    
    @IBAction func toggleFolderEncryption(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared(),
            let projects = vc.sidebarOutlineView.getSelectedProjects() else { return }
        
        guard let firstProject = projects.first  else { return }
        
        if firstProject.isEncrypted {
            vc.getMasterPassword() { password in
                self.decrypt(projects: projects, password: password)
            }
        } else {
            vc.getMasterPassword(forEncrypt: true) { password in
                self.encrypt(projects: projects, password: password)
            }
        }
    }
    
    @IBAction func toggleFolderLock(_ sender: NSMenuItem) {
        guard let vc = ViewController.shared(),
            let projects = vc.sidebarOutlineView.getSelectedProjects() else { return }
        
        guard let firstProject = projects.first  else { return }
        
        // Lock password exist
        if firstProject.password != nil {
            lock(projects: projects)
            
        // Unlock
        } else {
            let action = sender.identifier?.rawValue
            vc.getMasterPassword() { password in
                self.unlock(projects: projects, password: password, action: action)
            }
        }
    }
    
    public func decrypt(projects: [Project], password: String) {
        var decryptedQty = 0
        for project in projects {
            let decrypted = project.decrypt(password: password)
            decryptedQty = decrypted.count
            self.showTags(notes: decrypted)
        }
        
        guard decryptedQty > 0 else {
            self.wrongPassAlert()
            return
        }
        
        DispatchQueue.main.async {
            guard let vc = ViewController.shared() else { return }

            vc.notesTableView.disableLockedProject()
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
        
        if dstProject != nil, let srcParent = srcProject.parent, !srcParent.isRoot || srcParent.isExternal {
            srcIndex = srcParent.child.firstIndex(where: { $0 === srcProject })
        } else {
            srcIndex = sidebarItems.firstIndex(where: { $0 as? Project === srcProject })
        }
                
        // Disallow move from root to external
        if let dstProject = dstProject, dstProject.isExternal, !srcProject.isExternal && srcProject.parent == nil {
            return false
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
            srcProject.parent === proposedProject.parent,
            srcProject.isExternal == proposedProject.isExternal {
            return true
        }
        
        if sidebarItems.indices.contains(dstIndex), sidebarItems[dstIndex] as? Project == nil {
            return false
        }
        
        if sidebarItems.indices.contains(dstIndex + 1),
            let proposedProject = sidebarItems[dstIndex + 1] as? Project,
            srcProject.parent === proposedProject.parent,
            srcProject.isExternal == proposedProject.isExternal {
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


    public func removeProject(project: Project) {
        guard let vc = ViewController.shared(), storage.projectExist(url: project.url) else { return }

        selectedProjects?.removeAll(where: { $0 === project })

        if UserDataService.instance.lastProject?.path == project.url.path {
            self.viewDelegate?.cleanSearchAndEditArea()

            selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        self.storage.removeBy(project: project)

        guard vc.isVisibleSidebar() else { return }
        
        if let parent = project.parent, !parent.isRoot {
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

    public func insertProject(url: URL) {
        guard !storage.projectExist(url: url) else { return }
        guard !["assets", ".cache", "i", ".Trash"].contains(url.lastPathComponent) else { return }
        guard let parent = storage.findParent(url: url) else { return }
        
        let project = Project(storage: storage, url: url, parent: parent)
        parent.child.insert(project, at: 0)

        storage.assignTree(for: project)

        let notes = project.fetchNotes()
        for note in notes {
            note.forceLoad()
        }

        storage.noteList.append(contentsOf: notes)

        if let vc = ViewController.shared(), vc.isVisibleSidebar() {
            if !parent.isRoot || parent.isExternal {
                insertItems(at: [0], inParent: parent, withAnimation: .effectFade)
            } else {
                let position = getRootProjectPosition(for: project)
                sidebarItems?.insert(project, at: position)
                self.insertItems(at: [position], inParent: nil, withAnimation: .effectFade)
            }
        }

        viewDelegate?.fsManager?.reloadObservedFolders()
    }
    
    public func createProject(name: String, parent: Project) {
        guard name.count > 0 else { return }
        
        do {
            let projectURL = parent.url.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: false, attributes: nil)
        } catch {
            let alert = NSAlert()
            alert.messageText = error.localizedDescription
            alert.runModal()
        }
    }
    
    private func addRoot() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.begin { (result) -> Void in
            if result == .OK {
                guard let url = openPanel.url else {
                    return
                }
                
                guard !self.storage.projectExist(url: url) else {
                    return
                }
                
                let bookmark = SandboxBookmark.sharedInstance()
                _ = bookmark.load()
                bookmark.store(url: url)
                bookmark.save()
                
                let newProject =
                    Project(
                        storage: self.storage,
                        url: url,
                        isRoot: true,
                        isExternal: true
                    )
                
                self.storage.assignTree(for: newProject) { projects in
                    for project in projects {
                        self.storage.loadNotes(project)
                    }

                    self.reloadSidebar(reloadManager: true)
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
            if let si = item(atRow: i) as? SidebarItem, let project = si.project, si.tag == nil {
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
            if next.type == .Label && next.project == nil {
                let j = i + 1

                guard let si = sidebarItems, si.indices.contains(j) else { return }

                if let next = si[j] as? SidebarItem, next.type != .Label {
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
            if next.type == .Label && next.project == nil {
                let j = i - 1

                guard let si = sidebarItems, si.indices.contains(j) else { return }

                if let next = si[j] as? SidebarItem, next.type != .Label {
                    selectRowIndexes([j], byExtendingSelection: false)
                    return
                }

                return
            }
        }

        selectRowIndexes([i], byExtendingSelection: false)
    }

    private func getSelectedProject() -> Project? {
        guard let vc = ViewController.shared(), let v = vc.sidebarOutlineView else { return nil }

        if let project = v.item(atRow: v.selectedRow) as? Project {
            return project
        }

        if let sidebarItem = v.item(atRow: v.selectedRow) as? SidebarItem, let project = sidebarItem.project {
            return project
        }

        return nil
    }

    private func getSelectedProjects() -> [Project]? {
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
    
    @objc public func reloadSidebar(reloadManager: Bool = false) {
        guard let vc = ViewController.shared() else { return }

        if reloadManager {
            vc.fsManager?.restart()
        } else {
            vc.fsManager?.reloadObservedFolders()
        }

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
            projects = storage.getProjects().filter({ !$0.isTrash && !$0.isArchive && $0.settings.showInCommon })
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

    public func getRootProjectPosition(for project: Project) -> Int {
        guard let offset = sidebarItems?.firstIndex(where: { ($0 as? SidebarItem)?.project?.isDefault == true || ($0 as? Project)?.isDefault == true }) else {
            return sidebarItems?.count ?? 0
        }

        guard var projects = sidebarItems?
            .filter({
                ($0 as? Project) !== nil &&
                ($0 as? Project)?.isExternal == false &&
                ($0 as? Project)?.isArchive == false &&
                ($0 as? Project)?.isTrash == false
            }) as? [Project] else {
            return sidebarItems?.count ?? 0
        }

        projects.append(project)

        let sorted = projects.sorted(by: { $0.label.lowercased() < $1.label.lowercased() })
        if let index = sorted.firstIndex(where: { $0 === project }) {
            return index + offset + 1
        }

        return sidebarItems?.count ?? 0
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

                if let row = rowView(atRow: index, makeIfNecessary: false), let cell = row.view(atColumn: 0) as? SidebarCellView {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        cell.applySelectedFirstResponder()
                    }
                }
            }
        }
    }
}
